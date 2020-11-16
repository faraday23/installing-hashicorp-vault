################# Installing Vault ##########################

#For Windows
$vaultVersion = "1.0.1"
Invoke-WebRequest -Uri https://releases.hashicorp.com/vault/$vaultVersion/vault_$($vaultVersion)_windows_amd64.zip -OutFile .\vault_$($vaultVersion)_windows_amd64.zip
Expand-Archive .\vault_$($vaultVersion)_windows_amd64.zip
cd .\vault_$($vaultVersion)_windows_amd64
#Copy vault executable to a location include in your path variable

#For Linux
VAULT_VERSION="1.0.1"
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

#Install unzip if necessary
sudo apt install unzip -y
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin/

#chocolatey https://chocolatey.org/packages       (fastest way)
choco install vault

#verify installation of vault 
1.open bash 
2.type 'vault'

################# Starting the Dev server ######################

#Start the Dev server for vault
vault server -dev 

#Set env variable
#For Linux/MacOS
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=AddYourVaultTokenHere

#For Windows
$env:VAULT_ADDR = "http://127.0.0.1:8200"
$env:VAULT_TOKEN = "AddYourVaultTokenHere"
$headers = @{
    "X-Vault-Token" = $env:VAULT_TOKEN
}

#Log into the vault server
#Use the root token from the output
vault login

#verify server is running
vault status

############## Writing/Deleting secrets to Vault ######################

#Write a secret
vault kv put secret/hg2g answer=42

#For Linux
curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST \
 --data @marvin.json $VAULT_ADDR/v1/secret/data/marvin

#For Windows
Invoke-WebRequest -Method Post -Uri $env:VAULT_ADDR/v1/secret/data/marvin `
 -UseBasicParsing -Headers $headers -Body (get-content marvin.json)

#Get a secret
vault kv get secret/hg2g

#For Linux
#Install jq if necessary
sudo apt install jq -y
curl --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/secret/data/marvin | jq

#For Windows
Invoke-WebRequest -Method Get -Uri $env:VAULT_ADDR/v1/secret/data/marvin `
 -UseBasicParsing -Headers $headers

#Put a new secret in and a new value for an existing secret
vault kv put secret/hg2g answer=54 ford=prefect
vault kv get secret/hg2g

#Delete the secrets
vault kv delete secret/hg2g
vault kv get secret/hg2g

#For Linux
curl --header "X-Vault-Token: $VAULT_TOKEN" --request DELETE $VAULT_ADDR/v1/secret/data/marvin

#For Windows
Invoke-WebRequest -Method Delete -Uri $env:VAULT_ADDR/v1/secret/data/marvin `
 -UseBasicParsing -Headers $headers

############## Enable a secretes engine in Vault ######################
#Enable secrets engine
vault secrets enable -path=kv kv

#enable secrets engine
vault secrets enable kv

#verify secrets engine is installed
vault secrets list

#write secrets to engine config
#Take a few moments to read and write some data to the new kv secrets engine enabled at kv/. Here are a few ideas to get started.
#To create secrets, use the kv put command.
vault kv put kv/hello target=world

#To read the secrets stored in the kv/hello path, use the kv get command.
vault kv get kv/hello

#Creat secrets at the kv/my-secret path.
vault kv put kv/my-secret value="s3c(eT"

#Delete the secrets at kv/my-secret.
vault kv delete kv/my-secret

#List existing keys at the kv path.
vault kv list kv/

#When a secrets engine is no longer needed, it can be disabled. When a secrets engine is disabled, all secrets are revoked and the corresponding 
#Vault data and configuration is removed.
vault secrets disable kv/

############## Azure Secrets Engine vault ###################### - https://www.vaultproject.io/docs/secrets/azure#azure-secrets-engine

#Enable the Azure secrets engine
vault secrets enable azure

#Configure the secrets engine with account credentials:
vault write azure/config \
subscription_id=$AZURE_SUBSCRIPTION_ID \
tenant_id=$AZURE_TENANT_ID \
client_id=$AZURE_CLIENT_ID \
client_secret=$AZURE_CLIENT_SECRET

#To configure a role called "my-role" with an existing service principal:
vault write azure/roles/my-role application_object_id=<existing_app_obj_id> ttl=1h

#another example
vault write azure/roles/edu-app ttl=1h azure_roles=-<<EOF
    [
      {
        "role_name": "Contributor",
        "scope": "/subscriptions/<Subscription_ID>/resourceGroups/vault-education"
      }
    ]
EOF

#After the secrets engine is configured and a user/machine has a Vault token with the proper permissions, it can generate credentials. 
#The usage pattern is the same whether an existing or dynamic service principal is used.
#To generate a credential using the "my-role" role:
vault read azure/creds/my-role


############## Seal/Unseal with vault ######################

#During initialization, the encryption keys are generated, unseal keys are created, and the initial root token is setup. 
#To initialize Vault use
vault operator init

#Begin unsealing the Vault:
vault operator unseal

#As a root user, you can reseal the Vault with vault operator seal. A single operator is allowed to do this. 
#This lets a single operator lock down the Vault in an emergency without consulting other operators.
vault operator seal


################# Setting environment variables ######################
#Skip if you've already done this in the current session
#Set env variable
#For Linux/MacOS
export VAULT_ADDR=http://127.0.0.1:8200
#For Windows
$env:VAULT_ADDR = "http://127.0.0.1:8200"

# use this for testing locally
# provider.vault.address=http://127.0.0.1:8200
#Unseal Key: +93THCYvUdzEY*********bmofDmAVkn3m5A=
#export VAULT_ADDR=http://127.0.0.1:8200 
#export VAULT_TOKEN=s.vldkM********a0jowRBI

################# Enable database secrets engine ######################
#You are going to need an instance of MySQL running somewhere.  I use
#the Bitnami image on Azure, but you could do it locally instead.  You
#will need to open port 3306 on the remote instance to let Vault talk
#to it properly

#Enable the database secrets engine
vault secrets enable database

#Change <YourPublicIP> to your public IP address if you're using a remote
#MySQL instance

#SSH into the MySQL instance and run the follow commands.

#Configure MySQL roles and permissions
mysql -u root -p
CREATE ROLE 'dev-role';
CREATE USER 'vault'@'<YourPublicIP>' IDENTIFIED BY 'AsYcUdOP426i';
CREATE DATABASE devdb;
GRANT ALL ON *.* TO 'vault'@'<YourPublicIP>';
GRANT GRANT OPTION ON devdb.* TO 'vault'@'<YourPublicIP>';

#Change <MYSQL_IP> to the IP address of the MySQL server
#Configure the MySQL plugin
vault write database/config/dev-mysql-database \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(MY_SQL_IP:3306)/" \
    allowed_roles="dev-role" \
    username="vault" \
    password="AsYcUdOP426i"

#Configure a role to be used
vault write database/roles/dev-role \
    db_name=dev-mysql-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON devdb.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"

#Generate credentials on the DB from the role
vault read database/creds/dev-role

#Validate that the user has been created on MySQL and that the proper
#permissions have been applied
SELECT User FROM mysql.user;
SHOW GRANTS FOR 'username';

#Renew the lease
vault lease renew -increment=3600 database/creds/dev-role/LEASE_ID

vault lease renew -increment=96400 database/creds/dev-role/LEASE_ID

#Revoke the lease
vault lease revoke database/creds/dev-role/LEASE_ID


# read credentials from database
vault read database/creds/db_role_readwritedelete

# output
Key      Value                           
password A1a-CBiQaK5T7WTe1Hum            
username v-root-db_role_re-nP6UZlyjS4VoJi

# Configure the database secrets engine with the connection credentials for the mysql database.
vault write database/config/quickstartdb \
      plugin_name=mysql-database-plugin \
      allowed_roles="*" \
      connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" -force

vault write database/config/quickstartdb -plugin_name=mysql-database-plugin -allowed_roles="*" -connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" -force

# Configure vault with proper plugin and connection information
vault write database/config/quickstartdb \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" \
    allowed_roles="db_role_readwritedelete" \
    username="v-root-db_role_re-nP6UZlyjS4VoJi" \
    password="A1a-CBiQaK5T7WTe1Hum"

vault write database/config/quickstartdb -plugin_name=mysql-database-plugin -connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" -allowed_roles="db_role_readwritedelete" -username="v-root-db_role_re-nP6UZlyjS4VoJi" -password="A1a-CBiQaK5T7WTe1Hum" -force


# Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:
vault write database/roles/my-role \
    db_name=quickstartdb \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
    default_ttl="1h" \
    max_ttl="24h"


# rotating root credentials
vault write database/config/quickstartdb \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" \
    root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" \
    allowed_roles="db_role_readwritedelete" \
    username="v-root-db_role_re-nP6UZlyjS4VoJi" \
    password="A1a-CBiQaK5T7WTe1Hum"

vault write database/config/quickstartdb -plugin_name=mysql-database-plugin -connection_url="{{username}}:{{password}}@tcp(demo.mysql.database.azure.com:3306)/quickstartdb" -root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" -allowed_roles="db_role_readwritedelete" -username="v-root-db_role_re-nP6UZlyjS4VoJi" -password="A1a-CBiQaK5T7WTe1Hum" -force

# Create a role named 'readonly' with TTL of 1 hour.
vault write database/roles/readonly db_name=quickstartdb \
         creation_statements="CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";" \
         default_ttl=1h max_ttl=24h

vault write database/roles/db_role_readwritedelete db_name=quickstartdb -creation_statements="CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";" -default_ttl=1h max_ttl=24h

# Now, get a new set of database credentials.
vault read database/creds/db_role_readwritedelete

# output 
Key      Value                           
password A1a-4siXd32CevTYtkbv            
username v-root-db_role_re-Hgi0axoWDJzaVN


# manage ttl leases,  The credentials are managed by the lease ID and remain valid for the lease duration (TTL) or until revoked. Once revoked the credentials are no longer valid.
vault list sys/leases/lookup/database/creds/db_role_readwritedelete




############## EOF ######################