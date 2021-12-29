# amplifica-infra

Repositório que contém a infraestrutura como código do projeto Amplifica

## Autenticação

Antes de mais nada, para interagir via CLI na conta d'AzMina na AWS é preciso
usar MFA.

Para o corrente projeto, utilizaremos o usuário da aws "amplifica-bot", criado
com permissões estritas para as necessidades do projeto.

Para autenticação usando MFA, é recomendada a leitura dos seguintes materiais:
- https://levelup.gitconnected.com/aws-cli-automation-for-temporary-mfa-credentials-31853b1a8692
- https://aws.amazon.com/pt/premiumsupport/knowledge-center/authenticate-mfa-cli/

No presente caso, estamos usando dois scripts para automatizar a autenticação:

### _aws_mfa

Script que faz a autenticação e gera um token temporário de acesso, salvando-o
em um arquivo ("~/.aws/token_file" por padrão):

<details>
<summary> Código do shell script `_aws_mfa`:</summary>

```
#!/bin/bash
#
# Sample for getting temp session token from AWS STS
#
# aws --profile youriamuser sts get-session-token --duration 3600 \
# --serial-number arn:aws:iam::012345678901:mfa/user --token-code 012345
#
# Once the temp token is obtained, you'll need to feed the following environment
# variables to the aws-cli:
#
# export AWS_ACCESS_KEY_ID='KEY'
# export AWS_SECRET_ACCESS_KEY='SECRET'
# export AWS_SESSION_TOKEN='TOKEN'

AWS_CLI=$(command -v aws)

if ! command -v aws; then
  echo "AWS CLI is not installed; exiting"
  exit 1
else
  echo "Using AWS CLI found at ${AWS_CLI}"
fi

# 1 or 2 args ok
if [[ $# -ne 1 && $# -ne 2 ]]; then
  echo "Usage: $0 <MFA_TOKEN_CODE> <AWS_CLI_PROFILE>"
  echo "Where:"
  echo "   <MFA_TOKEN_CODE> = Code from virtual MFA device"
  echo "   <AWS_CLI_PROFILE> = aws-cli profile usually in ${HOME}/.aws/config"
  exit 2
fi

echo "Reading config..."
if [ ! -r ~/.aws/mfa.cfg ]; then
  echo "No config found.  Please create your mfa.cfg.  See README.txt for more info."
  exit 2
fi

AWS_CLI_PROFILE=${2:-default}
if [[ "${AWS_CLI_PROFILE}" == "default" ]]; then
    if [[ "${AWS_PROFILE:-undefined}" != "undefined" ]]; then
        AWS_CLI_PROFILE="${AWS_PROFILE}"
    fi
fi

MFA_TOKEN_CODE=$1
if [[ "${AWS_MFA:-none}" == "none" ]]; then
    ARN_OF_MFA=$(grep "^${AWS_CLI_PROFILE}" ~/.aws/mfa.cfg | cut -d '=' -f2- | tr -d '"')
else
    ARN_OF_MFA="${AWS_MFA}"
fi

echo "AWS-CLI Profile: ${AWS_CLI_PROFILE}"
echo "MFA ARN: ${ARN_OF_MFA}"
echo "MFA Token Code: ${MFA_TOKEN_CODE}"

echo "Your Temporary Creds:"
if [[ ! -f ~/.aws/token_file ]]; then
    touch ~/.aws/token_file
fi
aws --profile "${AWS_CLI_PROFILE}" sts get-session-token --duration 129600 \
  --serial-number "${ARN_OF_MFA}" --token-code "${MFA_TOKEN_CODE}" --output text \
  | awk '{printf("export AWS_ACCESS_KEY_ID=\"%s\"\nexport AWS_SECRET_ACCESS_KEY=\"%s\"\nexport AWS_SESSION_TOKEN=\"%s\"\nexport AWS_SECURITY_TOKEN=\"%s\"\n",$2,$4,$5,$5)}' | tee ~/.aws/token_file
```
</details>

Para facilitar o uso do script acima, defina duas variáveis de ambiente:
AWS_PROFILE e AWS_MFA, com o respectivo profile e ID (ARN) do MFA a ser
utilizado.

Além dele, temos uma outra função/alias que serve para chamar o script acima e
carregar o token gerado no ambiente.

<details>
<summary>setToken()</summary>
setToken() {
    <path_to__aws_mfa_script> $1 $2
    let EX_CODE=?
    if [ $EX_CODE -ne 0 ]; then
        return $EX_CODE
    fi
    source ~/.aws/token_file
    echo "Your creds have been set in your env."
}
alias mfa=setToken
</details>

Finalmente, para usar basta chamar:
`mfa <token>` com o token TOTP do MFA utilizado.
