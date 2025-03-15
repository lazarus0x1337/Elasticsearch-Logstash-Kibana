#!/bin/bash
set -e  # Stop script on first error
CERTS_DIR="/usr/share/elasticsearch/config/certs"

# Generating the Certificate Authority :ensures that the certificates it signs are trusted by anyone using them
# The --silent flag disables interactive prompts.
# The --pem flag generates certificates in PEM format.
mkdir  -p /usr/share/elasticsearch/config/certs

if [ ! -f "$CERTS_DIR/ca.zip" ]; then
    echo "🚀 Generating CA certificate..."
    bin/elasticsearch-certutil ca --silent --pem -out "$CERTS_DIR/ca.zip"
    unzip "$CERTS_DIR/ca.zip" -d "$CERTS_DIR"
    rm -rf "$CERTS_DIR/ca.zip"
fi

#/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
# after testing this cmd to change pass : we have this error :
# java.security.cert.CertificateException: No subject alternative names present
# instances.yml file is a configuration file used by Elasticsearch's elasticsearch-certutil
# tool to generate SSL/TLS certificates with Subject Alternative Names (SANs).

# example instance.yml

# instances:
#   - name: "instance"       # Name of the certificate (e.g., "elasticsearch")
#     dns:
#       - "localhost"       # DNS names for the certificate
#       - "elasticsearch"   # Docker service name (for container-to-container communication)
#     ip:
#       - "127.0.0.1"       # Localhost IP
#       - "172.20.0.2"      # Container IP (adjust based on your Docker network)

if [ ! -f config/certs/certs.zip ]; then
    echo "Creating certs";
    echo -ne \
    "instances:\n"\
    "  - name: elasticsearch\n"\
    "    dns:\n"\
    "      - elasticsearch\n"\
    "      - localhost\n"\
    "    ip:\n"\
    "      - 127.0.0.1\n"\
    "  - name: logstash\n"\
    "    dns:\n"\
    "      - logstash\n"\
    "      - localhost\n"\
    "    ip:\n"\
    "      - 127.0.0.1\n"\
    > "/usr/share/elasticsearch/instances.yml";
    bin/elasticsearch-certutil cert --silent --pem -out "$CERTS_DIR/certs.zip" --in /usr/share/elasticsearch/instances.yml --ca-cert "$CERTS_DIR/ca/ca.crt" --ca-key "$CERTS_DIR/ca/ca.key";
    unzip "$CERTS_DIR/certs.zip" -d "$CERTS_DIR";
    rm -rf "$CERTS_DIR/certs.zip"
fi;

#set permission : 
echo "✅ Certificate setup complete. Starting Elasticsearch..."
chown -R elasticsearch:elasticsearch "$CERTS_DIR"

exec gosu elasticsearch bin/elasticsearch 

# Wait for Elasticsearch to start
echo "Waiting for Elasticsearch to start..."
until curl -k --cacert config/certs/ca/ca.crt https://localhost:9200; do
    sleep 3
done

# # Reset the password
echo "Resetting password for elastic user..."
echo "y" | bin/elasticsearch-reset-password -u elastic -i <<< "changeme"
