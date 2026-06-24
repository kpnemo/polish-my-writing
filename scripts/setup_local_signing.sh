#!/usr/bin/env bash
# One-time setup: create a STABLE self-signed code-signing identity for local
# testing. A stable signature means macOS keeps the Accessibility (TCC) grant
# across rebuilds, instead of re-prompting every time an ad-hoc build changes.
#
# Gatekeeper will still mark this cert untrusted — that's fine; it only matters
# for distribution (use a real Developer ID for the notarized .dmg). For running
# locally and keeping the Accessibility grant, this is all that's needed.
set -euo pipefail

CERT="Polish My Writing Dev"

if security find-identity -p codesigning | grep -q "$CERT"; then
  echo "Identity already exists: $CERT"
  exit 0
fi

echo "Creating self-signed code-signing identity \"$CERT\"…"
OSSL=$(openssl version)
LEGACY=""; case "$OSSL" in *"OpenSSL 3"*) LEGACY="-legacy";; esac

cat > /tmp/pmw_openssl.cnf <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = Polish My Writing Dev
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -keyout /tmp/pmw_key.pem -out /tmp/pmw_cert.pem \
  -days 3650 -nodes -config /tmp/pmw_openssl.cnf
# Apple's keychain needs the legacy PKCS12 MAC/PBE algorithms.
openssl pkcs12 -export $LEGACY -macalg sha1 -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES \
  -inkey /tmp/pmw_key.pem -in /tmp/pmw_cert.pem -out /tmp/pmw.p12 -passout pass:pmw -name "$CERT"
# -A lets codesign use the key without a keychain prompt on every build.
security import /tmp/pmw.p12 -k ~/Library/Keychains/login.keychain-db -P pmw -A -T /usr/bin/codesign
rm -f /tmp/pmw_key.pem /tmp/pmw_cert.pem /tmp/pmw.p12 /tmp/pmw_openssl.cnf

echo "Done. Identity \"$CERT\" created (shown as CSSMERR_TP_NOT_TRUSTED — expected)."
