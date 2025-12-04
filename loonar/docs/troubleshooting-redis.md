# Troubleshooting: Redis MISCONF Error

## Problema

Ao acessar o Superset UI, o seguinte erro aparece:

```json
{
  "errors": [{
    "message": "Command # 1 (SETEX ...) of pipeline caused error: MISCONF Redis is configured to save RDB snapshots, but it's currently unable to persist to disk. Commands that may modify the data set are disabled, because this instance is configured to report errors during writes if RDB snapshotting fails (stop-writes-on-bgsave-error option). Please check the Redis logs for details about the RDB error.",
    "error_type": "GENERIC_BACKEND_ERROR",
    "level": "error"
  }]
}
```

## Causa

O Redis está configurado para salvar snapshots RDB no disco (`save 300 100` no `redis.conf`) mas não consegue escrever no diretório `/data` devido a problemas de permissões.

O container Redis roda como usuário `999:999` (conforme definido no `docker-compose-loonar.yml`), mas o diretório `./volumes/redis` foi criado com permissões incorretas (proprietário `root`).

## Logs do Redis

```bash
docker logs superset_cache --tail 20
```

Você verá erros como:
```
Failed opening the temp RDB file temp-XXX.rdb (in server root dir /data) for saving: Permission denied
Background saving error
```

## Solução Rápida

```bash
# Corrigir permissões do diretório Redis
sudo chown -R 999:999 volumes/redis
sudo chmod -R 755 volumes/redis

# Reiniciar o container Redis
docker restart superset_cache

# Reiniciar containers do Superset
docker restart superset_app superset_worker superset_worker_beat
```

## Solução Permanente

O script `loonar/setup.sh` foi atualizado para configurar automaticamente as permissões corretas:

```bash
# Execute o setup antes de iniciar os containers
cd loonar
./setup.sh
./up.sh
```

## Verificação

1. Verificar se Redis está salvando corretamente:
```bash
docker logs superset_cache --tail 20
# Deve mostrar: "Background saving terminated with success"
```

2. Testar o Superset:
```bash
curl -f http://localhost:8088/health
# Deve retornar: ok
```

## Configuração do Redis

Em `docker/redis/redis.conf`:

```conf
# Salvar snapshot a cada 5 minutos se houver 100 mudanças
save 300 100

# Parar escritas se falhar o save (previne perda de dados)
stop-writes-on-bgsave-error yes

# Diretório onde o RDB será salvo
dir /data
```

Em `docker-compose-loonar.yml`:

```yaml
services:
  redis:
    user: "999:999"  # Usuário Redis padrão
    volumes:
      - ./volumes/redis:/data  # DEVE ter permissões 999:999
```

## Prevenção

- Sempre execute `loonar/setup.sh` antes de iniciar os containers
- Não modifique manualmente as permissões de `volumes/redis`
- Se recriar os volumes, execute o setup novamente

## Referências

- [Redis RDB Persistence](https://redis.io/docs/management/persistence/)
- [Docker Redis Official Image](https://hub.docker.com/_/redis)
- [Superset Caching](https://superset.apache.org/docs/installation/cache)
