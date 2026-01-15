#!/usr/bin/env bash
set -e

if [ -z "$SLACK_WEBHOOK" ]; then
  echo "SLACK_WEBHOOK não definido"
  exit 1
fi

WATCH_DIR="/watch"
DEBOUNCE=3
LAST_RUN=0

cd "$WATCH_DIR"

# Certificar que o git confia no diretório
git config --global --add safe.directory /watch

# Inicializar snapshot se não existir
if [ ! -d ".git" ]; then
  echo "Inicializando repositório de auditoria..."
  git init
  git config user.name "Auditor"
  git config user.email "auditor@local"
  git add -A .
  git commit -m "Snapshot Inicial"
fi

echo "Auditor ativo em $WATCH_DIR. Monitorando alterações..."

# Usar modo monitor (-m) para receber streaming de eventos
inotifywait -m -r \
  --exclude $WATCH_EXCLUDE \
  -e modify,create,delete,move \
  --format '%e|%f|%w' \
  "$WATCH_DIR" | while read EVENT; do

  # Debounce simples para evitar spam de eventos rápidos (ex: salvar vários arquivos)
  NOW=$(date +%s)
  if [ $((NOW - LAST_RUN)) -lt $DEBOUNCE ]; then
    continue
  fi
  LAST_RUN=$NOW

  echo "Evento: $EVENT"
  
  # Esperar um pouco para o sistema de arquivos estabilizar
  sleep 1

  ACTION=$(echo "$EVENT" | cut -d'|' -f1)
  FILE=$(echo "$EVENT" | cut -d'|' -f2)
  PATH_DIR=$(echo "$EVENT" | cut -d'|' -f3)

  # Adicionar mudanças ao git e extrair o diff
  git add -A .
  DIFF=$(git diff --cached --no-color | head -c 4000)

  if [ -z "$DIFF" ]; then
    echo "Nenhuma mudança de conteúdo detectada para $FILE."
    continue
  fi

  # Consolidar o commit de auditoria
  git commit -m "Audit: $ACTION $FILE" --allow-empty

  # ESCAPAR CONTEÚDO PARA JSON USANDO PYTHON (Mais seguro)
  # Criamos o JSON estruturado para o Slack
  python3 -c "
import json, os, requests

webhook_url = os.environ.get('SLACK_WEBHOOK')
diff_content = \"\"\"$DIFF\"\"\"
action = \"$ACTION\"
file_path = \"$PATH_DIR$FILE\"

payload = {
    'attachments': [
        {
            'color': '#36a64f',
            'title': f'[${PROJECT_NAME}] 🚨 Alteração Detectada ({action})',
            'text': f'*Arquivo:* `{file_path}`\n\n```\n{diff_content}\n```',
            'mrkdwn_in': ['text']
        }
    ]
}

requests.post(webhook_url, json=payload)
" 2>/dev/null || {
    # Fallback caso o python falhe (ex: requests não instalado, mas builtin json deve funcionar)
    echo "Enviando via cURL (fallback)..."
    cat <<EOF > /tmp/payload.json
{
  "attachments": [
    {
      "color": "#36a64f",
      "title": "[${PROJECT_NAME}]\n🚨 Alteração Detectada ($ACTION)",
      "text": "*Arquivo:* \`${PATH_DIR}${FILE}\` \n\n \`\`\`\n${DIFF}\n\`\`\`",
      "mrkdwn_in": ["text"]
    }
  ]
}
EOF
    curl -s -X POST -H "Content-type: application/json" --data-binary @/tmp/payload.json "$SLACK_WEBHOOK" > /dev/null
}

  echo "Diff enviado para o Slack ($FILE)."
done
