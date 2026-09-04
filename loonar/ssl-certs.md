# Certificados SSL

## Diretório dos certificados

```text
<repo root>/loonar/ssl-certs/
```

Esse diretório é montado como somente leitura no container Nginx em:

```text
/etc/nginx/certs/
```

## Nomes obrigatórios

| Arquivo no host | Caminho no Nginx | Conteúdo |
|---|---|---|
| `loonar/ssl-certs/fullchain.pem` | `/etc/nginx/certs/fullchain.pem` | Certificado do servidor seguido dos certificados intermediários |
| `loonar/ssl-certs/privkey.pem` | `/etc/nginx/certs/privkey.pem` | Somente a chave privada correspondente ao certificado do servidor |
| `loonar/ssl-certs/ca-bundle.crt` | `/etc/nginx/certs/ca-bundle.crt` | Certificados CA confiáveis em formato PEM |

Esses caminhos são configurados por `SSL_CERT`, `SSL_KEY` e `SSL_TRUSTED` no `loonar/.env`. Não altere os nomes sem atualizar essas variáveis.

## Preparação dos arquivos

```bash
chmod 600 loonar/ssl-certs/privkey.pem
```


### 2. Full chain

O arquivo `fullchain.pem` deve começar pelo certificado do servidor e, depois, conter o(s) certificado(s) intermediário(s) da autoridade certificadora, nesta ordem:

```text
certificado do servidor
certificado intermediário
outros intermediários, se houver
```

Para gerar o fullchain.pem caso não o possua:

```bash
cat <certificado-do-servidor>.crt \
    <certificado-intermediario>.crt \
    > loonar/ssl-certs/fullchain.pem
```

Inclua outros intermediários, se existirem, na sequência indicada pela autoridade certificadora.

Não use somente um certificado raiz como `fullchain.pem` e não inclua a chave privada nesse arquivo.

### 3. Bundle de CAs confiáveis

`ca-bundle.crt` deve conter apenas certificados CA em PEM. Use o bundle fornecido pela autoridade certificadora.

Não inclua o certificado do servidor, a chave privada ou parâmetros Diffie-Hellman nesse bundle. Arquivos como `dhparams.pem` não são usados pelo template Nginx atual.

## Verificações antes do deploy

Na raiz do repositório, verifique se os três arquivos estão presentes:

```bash
ls -l loonar/ssl-certs/fullchain.pem \
      loonar/ssl-certs/privkey.pem \
      loonar/ssl-certs/ca-bundle.crt
```

Verifique o conteúdo PEM sem exibir a chave privada:

```bash
openssl x509 -in loonar/ssl-certs/fullchain.pem -noout -subject -issuer -ext subjectAltName
openssl x509 -in loonar/ssl-certs/ca-bundle.crt -noout -subject -issuer
```

O certificado e a chave devem formar um par. Para comparar as chaves públicas sem revelar a chave privada:

```bash
openssl x509 -in loonar/ssl-certs/fullchain.pem -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | sha256sum
openssl pkey -in loonar/ssl-certs/privkey.pem -pubout \
  | openssl pkey -pubin -outform der \
  | sha256sum
```

Os dois hashes devem ser iguais.

## Observações

- O Nginx está configurado com OCSP stapling; uma cadeia ou CA bundle inválidos podem impedir o serviço de iniciar ou gerar erros TLS.
- Os arquivos de chave privada devem permanecer fora do controle de versão. O `.gitignore` já ignora as chaves/certificados de desenvolvimento, mas confirme o estado do repositório antes de adicionar certificados reais.
- Execute `./loonar/up.sh` somente depois de preparar os três arquivos na raiz de `loonar/ssl-certs/`.

## Certificado temporário auto-gerado

Para testes ou uso temporário, é possível gerar uma CA local e um certificado do servidor assinado por ela. Esse certificado não é apropriado para produção e não será confiável automaticamente pelos navegadores; a CA local deverá ser instalada nos dispositivos clientes ou o navegador exibirá um alerta de segurança.

Execute os comandos a partir da raiz do repositório. O exemplo abaixo cria certificados válidos por 30 dias e usa o valor de `SUPERSET_HOST` definido em `loonar/.env`:

```bash
CERT_DIR="loonar/ssl-certs"
HOST="$(grep '^SUPERSET_HOST=' loonar/.env | cut -d '=' -f2- | tr -d '\"' | tr -d "'" | xargs)"

if [ -z "$HOST" ]; then
  echo "SUPERSET_HOST não está definido em loonar/.env" >&2
  exit 1
fi

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/temporary-ca.key" \
  -out "$CERT_DIR/temporary-ca.crt" \
  -days 30 -sha256 \
  -subj "/C=BR/O=Loonar/OU=Temporary/CN=Loonar Temporary CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

openssl req -newkey rsa:2048 -nodes \
  -keyout "$CERT_DIR/temporary-server.key" \
  -out "$CERT_DIR/temporary-server.csr" \
  -subj "/C=BR/O=Loonar/OU=Temporary/CN=$HOST"

openssl x509 -req \
  -in "$CERT_DIR/temporary-server.csr" \
  -CA "$CERT_DIR/temporary-ca.crt" \
  -CAkey "$CERT_DIR/temporary-ca.key" \
  -CAcreateserial \
  -out "$CERT_DIR/temporary-server.crt" \
  -days 30 -sha256 \
  -extfile <(printf "subjectAltName=DNS:%s\\nbasicConstraints=critical,CA:FALSE\\nkeyUsage=critical,digitalSignature,keyEncipherment\\nextendedKeyUsage=serverAuth\\n" "$HOST")

cp "$CERT_DIR/temporary-server.crt" "$CERT_DIR/fullchain.pem"
cp "$CERT_DIR/temporary-server.key" "$CERT_DIR/privkey.pem"
cp "$CERT_DIR/temporary-ca.crt" "$CERT_DIR/ca-bundle.crt"

chmod 600 "$CERT_DIR/privkey.pem" "$CERT_DIR/temporary-ca.key" "$CERT_DIR/temporary-server.key"
chmod 644 "$CERT_DIR/fullchain.pem" "$CERT_DIR/ca-bundle.crt"
```

Nesse cenário, o bundle usado pelo Nginx é a própria CA temporária:

```text
fullchain.pem  = temporary-server.crt
privkey.pem    = temporary-server.key
ca-bundle.crt  = temporary-ca.crt
```

O certificado `temporary-ca.crt` é o arquivo que deve ser instalado como autoridade confiável nos computadores, navegadores ou dispositivos que acessarão o Superset. Nunca distribua `temporary-ca.key` ou `privkey.pem`.

Depois de gerar os arquivos, valide a configuração e reinicie o serviço Nginx:

```bash
docker compose --env-file loonar/.env -f docker-compose-loonar.yml config >/dev/null
docker compose --env-file loonar/.env -f docker-compose-loonar.yml up -d --force-recreate nginx
```

Se o certificado temporário for substituído por um certificado real, substitua os três arquivos esperados na raiz de `loonar/ssl-certs/`, mantenha `SSL_CERT`, `SSL_KEY` e `SSL_TRUSTED` apontando para os caminhos padrão e recrie o serviço Nginx. Remova os arquivos temporários e a chave da CA quando não forem mais necessários.
