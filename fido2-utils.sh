#!/bin/sh
DISK="/dev/nvme0n1p3"

fido2_device() {
    device=$(fido2-token -L | sed 's/:.*//')
    if [ -z "$device" ] ; then
        return 1
    else
        echo "$device"
    fi
}

fido2_get_token() {
    token_id=$(cryptsetup luksDump "$1" | grep -E '^\s+[0-9]+: systemd-fido2$' | head -1 | sed -e 's/\s\+\([0-9]\+\):.*/\1/')
    cryptsetup token export "$1" --token-id=$token_id
}

fido2_is_pin_required() {
    pin_required=$(fido2_get_token "$1" | jq -r '."fido2-clientPin-required"')
    test "$pin_required" = "true"
}

fido2_authenticate() {
    token_json=$(fido2_get_token "$2")
    param_file=$(mktemp)
    use_pin=$(echo $token_json | jq -r '."fido2-clientPin-required"')
    if [ "$use_pin" = "true" ] ; then
        pin="$1"
    else
        pin=""
    fi

    dd if=/dev/urandom bs=1 count=32 2> /dev/null | base64 > $param_file
    echo $token_json | jq -r '."fido2-rp"' >> $param_file
    echo $token_json | jq -r '."fido2-credential"' >> $param_file
    echo $token_json | jq -r '."fido2-salt"' >> $param_file

    assert_flags="-G -h"
    assert_flags="$assert_flags -t up=$(echo $token_json | jq -r '."fido2-up-required"')"

    if [ "$use_pin" = "true" ] ; then
        assert_flags="$assert_flags -t pin=true"
        assert_flags="$assert_flags -t uv=$(echo $token_json | jq -r '."fido2-uv-required"')"
    fi

    assertion=$(echo -n "$pin" | setsid fido2-assert $assert_flags -i "$param_file" $(fido2_device) 2> /dev/null || (rm -f $param_file ; echo "Wrong PIN." 1>&2 ; exit 1))
    rm -f $param_file
    printf '%s' "$assertion" | tail -1
}
