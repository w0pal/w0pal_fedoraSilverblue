#!/usr/bin/bash
# Auto-load v4l2loopback with Secure Boot support
# Handles kernel updates by re-extracting and re-signing

MODDIR="/var/lib/v4l2loopback"
KVER="$(uname -r)"
KOFILE="${MODDIR}/v4l2loopback-${KVER}.ko"
SRCKO="/lib/modules/${KVER}/extra/v4l2loopback/v4l2loopback.ko.xz"
SIGNFILE="/usr/src/kernels/${KVER}/scripts/sign-file"
PRIVKEY="/etc/pki/akmods/private/private_key.priv"
PUBKEY="/etc/pki/akmods/certs/public_key.der"

mkdir -p "$MODDIR"

# If no .ko for current kernel, extract and sign
if [ ! -f "$KOFILE" ]; then
    echo "v4l2loopback: Building signed module for kernel ${KVER}..."

    if [ ! -f "$SRCKO" ]; then
        echo "ERROR: Module source not found: $SRCKO"
        exit 1
    fi

    # Extract
    xz -d -k "$SRCKO" --stdout > "$KOFILE"

    # Sign with MOK key
    if [ -f "$SIGNFILE" ] && [ -f "$PRIVKEY" ] && [ -f "$PUBKEY" ]; then
        "$SIGNFILE" sha256 "$PRIVKEY" "$PUBKEY" "$KOFILE"
        echo "v4l2loopback: Module signed successfully"
    else
        echo "ERROR: Signing tools/keys not found"
        rm -f "$KOFILE"
        exit 1
    fi

    # Set SELinux context so module_load is allowed
    chcon -t modules_object_t "$KOFILE" 2>/dev/null
fi

# Load module
/usr/sbin/insmod "$KOFILE" exclusive_caps=1 card_label="OBS Virtual Camera"
