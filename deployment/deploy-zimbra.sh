#!/bin/bash

DOMAIN=$1

export ZIMBRA_DIR=/opt/zimbra
export CERT_DIR=/etc/letsencrypt/live/$DOMAIN

if [[ -d $CERT_DIR ]] && [[ -d $ZIMBRA_DIR ]]; then

export ZIMBRA_SSL_DIR=$ZIMBRA_DIR/ssl/zimbra/commercial/
export ZIMBRA_SSL_DIR_TMP=$ZIMBRA_DIR/tmp-deploy-ssl

echo "Preparing certificates"

# Copy the certificates to tmp dir
mkdir $ZIMBRA_SSL_DIR_TMP
cp $CERT_DIR/privkey.pem $ZIMBRA_SSL_DIR_TMP/commercial.key
cp $CERT_DIR/cert.pem $ZIMBRA_SSL_DIR_TMP/commercial.crt
cp $CERT_DIR/chain.pem $ZIMBRA_SSL_DIR_TMP/commercial_ca.crt

# Append root cert
cat >> $ZIMBRA_SSL_DIR_TMP/commercial_ca.crt << EOF
-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----
EOF

chown -R zimbra:root $ZIMBRA_SSL_DIR_TMP

cd $ZIMBRA_DIR
su zimbra << EOF

echo "Deploying certificate"

rm $ZIMBRA_SSL_DIR/commercial.key
rm $ZIMBRA_SSL_DIR/commercial.crt
rm $ZIMBRA_SSL_DIR/commercial_ca.crt

cp $ZIMBRA_SSL_DIR_TMP/commercial.key $ZIMBRA_SSL_DIR/commercial.key
cp $ZIMBRA_SSL_DIR_TMP/commercial.crt $ZIMBRA_SSL_DIR/commercial.crt

$ZIMBRA_DIR/bin/zmcertmgr deploycrt comm $ZIMBRA_SSL_DIR_TMP/commercial.crt $ZIMBRA_SSL_DIR_TMP/commercial_ca.crt

echo "Restarting Zimbra"

$ZIMBRA_DIR/bin/zmcontrol restart

EOF

rm -rf $ZIMBRA_SSL_DIR_TMP

else
  echo "Domain does not exist"
fi
