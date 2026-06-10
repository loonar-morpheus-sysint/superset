# Caminho do certificado
$certPath = "superset-ca.crt"

# Importa para a loja de raiz confiável do computador local
Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\LocalMachine\Root
