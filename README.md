# amplifica-infra

Repositório que provisiona a infraestrutura e as aplicações do projeto
amplifica.

São três componentes.

1. Servidor
2. Dashboard (shiny app)
3. Crawler (código R/Rstudio/Rserver)

## 1. Servidor

O Servidor é provisionado utilizando terraform e o provisionamento acontece na
AWS, usando o serviço chamado _lightsail_ da AWS.

O código de provisionamento está na pasta "terraform".

Além de criar uma instância do lightsail, também temos um IP "fixo" (caso a
instância seja reprovisionada, mantém-se o IP público) e também é feita a
configuração do domínio "amplifica.azmina.com.br", gerenciado no Cloudflare.

Para o provisionamento da instância utilizamos o "userdata" passando o script
que se encontra em `terraform/scripts/bootstrap.sh` que é executado durante o
boot da instância. Esse script é utilizado para fazer as configurações
necessárias do servidor, incluindo instalar o shiny server e o rstudio server
(dentre outras).

Caso seja necessário instalar pacotes R para as aplicações que serão executadas
neste servidor, este é o arquivo a ser modificado.

## 2. Dashboard (Shiny App)

No projeto teremos um dashboard feito com shiny.
O código deste dashboard será automaticamente carregado deste repositório no
servidor. O código deve ficar no diretório `src/dashboard/` e será acessível em:
https://amplifica.azmina.com.br:3838

No CI temo um job que copia o código deste repositório no servidor.

## 3. Crawler

O terceiro componente é o crawler, que vai buscar dados do twitter e salvar no
banco de dados.
Por hora, a execução do crawler ainda não está automatizada, mas caso arquivos
de código R seja adicionados no diretório `src/crawler` do repositório ele será
copiado para a home do usuário `amplifica`. Este é o único usuário com acesso ao
Rstudio instalado no servidor e acessível em https://amplifica.azmina.com.br

# Configurações de CI

## Secrets (https://github.com/institutoazmina/amplifica-infra/settings/secrets/actions)

Para configurar este CI corretamente são necessárias os seguintes secrets:
    - AWS_DEFAULT_REGION
    - CLOUDFLARE_ACCOUNT_ID
        - https://www.youtube.com/watch?v=XkDBADKiKC0
    - CLOUDFLARE_API_TOKEN
        - https://developers.cloudflare.com/api/tokens/create
        - Aqui só precisamos de permissão de "EDIT DNS".
    - SSH_PRIV_KEY
        - Essa é uma chave SSH criada manualmente no padrão ed25519:
        - `ssh-keygen -t ed25519 -C "<email>"`

## Bucket S3 para o estado do terraform

Precisamos criar um S3 bucket na AWS para armazenar o arquivo de estado do
Terraform. Vamos chamá-lo de `<sample-nosso-bucket-do-terraform>`.

## AWS Role

Para que o CI do github consiga interagir com a AWS, precisamos de algumas
configurações.

Primeiro é preciso configurar um OpenID Connect (OIDC) provider:
https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

Depois, para o Role do IAM criado precisamos configurar algumas permissões:

1. lightsail (full access)
    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": "lightsail:*",
                "Resource": "*"
            }
        ]
    }
    ```
2. Acesso ao bucket do S3 que armazenará o estado do terraform:
    ```
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::<sample-nosso-bucket-do-terraform>"
            },
            {
                "Sid": "VisualEditor1",
                "Effect": "Allow",
                "Action": "s3:*Object",
                "Resource": "arn:aws:s3:::<sample-nosso-bucket-do-terraform>/*"
            }
        ]
    }
    ```

## Pontos de atenção

Como temos automação para os códigos do diretório `src/dashboard` e
`src/crwaler`, eventuais alterações nestes arquivos feitas diretamente no
servidor (via ssh ou via Rstudio web) serão perdidas quando o CI for executado.
Então cuidado para não perder seu trabalho, e lembre-se sempre de mantê-lo
"sincronizado" com o repositório.
