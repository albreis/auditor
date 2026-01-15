# Auditor

O Auditor é uma ferramenta leve para monitoramento de alterações em sistemas de arquivos, projetada para rodar em containers Docker. Ele detecta modificações, cria instantâneos automáticos via Git e envia notificações de **diff detalhado** para um canal do Slack.

## 🚀 Como Funciona

O serviço monitora um diretório montado em `/watch` usando `inotifywait`. Quando uma alteração é detectada:
1.  As mudanças são adicionadas a um repositório Git interno temporário.
2.  Um `git diff` é gerado para capturar exatamente o que mudou.
3.  O diff é formatado e enviado para o Slack via Webhook.
4.  Um commit automático é realizado para manter o controle do histórico de auditoria dentro do container.

## 🛠️ Configuração

O Auditor é configurado via variáveis de ambiente:

| Variável | Descrição | Exemplo |
| :--- | :--- | :--- |
| `SLACK_WEBHOOK` | URL do Webhook do Slack (Obrigatório) | `https://hooks.slack.com/services/...` |
| `PROJECT_NAME` | Nome do projeto para identificar no Slack | `meu-projeto.com` |
| `WATCH_EXCLUDE` | Regex de caminhos/arquivos para ignorar | `(\.git\|node_modules\|vendor)` |

## 📦 Exemplo de Uso (Docker Compose)

```yaml
services:
  auditor:
    image: ghcr.io/albreis/auditor:latest
    container_name: auditor
    restart: always
    volumes:
      - ./meu-projeto:/watch
    environment:
      SLACK_WEBHOOK: "https://hooks.slack.com/services/..."
      PROJECT_NAME: "Meu Projeto"
      WATCH_EXCLUDE: '(\.git|node_modules|vendor)'
```

## 🛠️ Desenvolvimento e Build

Para compilar a imagem localmente:

```bash
docker build -t auditor .
```

## 📝 Segurança

O script utiliza o Git interno para gerenciar os snapshots. Ele adiciona automaticamente o diretório `/watch` ao `safe.directory` do Git para evitar problemas de permissão quando montado como volume de diferentes usuários host.
