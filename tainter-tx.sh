#!/bin/bash

tainter_inputs_get_rdm ()
{
    ${clientname_cli} decoderawtransaction "$1" | grep -A2 "      \"vout\": [0-9]*," | grep -o "0014[0-f]\{40\}"
}

tainter_inputs_get_prevtx ()
{
    ${clientname_cli} decoderawtransaction "$1" | grep -B1 "      \"vout\": [0-9]*," | grep -o "[0-f]*" | grep -v '^d$'
}

tainter_inputs_get_pubkey ()
{
    ${clientname_cli} decoderawtransaction "$1" | grep -A2 '      "txinwitness"' | grep -A1 "30[0-f]\{100,\}83" | grep -o "0[23][0-f]\{64\}[^0-f]" | tr -d '"'
}

tainter_inputs_get_time ()
{
    ${clientname_cli} gettxout "$1" "$2" | grep "bestblock" | grep -o "[0-f]\{64\}" | ${clientname_cli} -stdin getblock | grep '"time"' | grep -o "[0-9]*"
}

tainter_get_spk ()
{
    ${clientname_cli} decodescript "$1" | grep "p2sh" | grep -o "[0-Z]\{35\}*" | ${clientname_cli} -stdin validateaddress  | grep "scriptPubKey" | grep -o "[0-f]\{46\}"
}

tainter_mkimport ()
{
    taint_tx="$1"
    clientname_cli="${2:-bitcoin-cli -testnet}"

    read redeemscript < <( tainter_inputs_get_rdm "${taint_tx}" )
    readarray -t prevtx < <( tainter_inputs_get_prevtx "${taint_tx}" )
    read pubkey < <( tainter_inputs_get_pubkey "${taint_tx}" )
    read timestamp < <( tainter_inputs_get_time "${prevtx[0]}" "${prevtx[1]}" )
    read scriptpubkey < <( tainter_get_spk "${redeemscript}" )

    echo -e "\nimport the tainter  :"
    printf '%s %s "jmtainter" false\n\n' "${clientname_cli} importpubkey" "${pubkey}"
    printf '%s %s[{"scriptPubKey":"%s","timestamp":%s,"redeemscript":"%s","pubkeys":["%s"],"internal":true,"watchonly":true}]%s\n\n' "${clientname_cli} importmulti" "'" "${scriptpubkey}" "${timestamp}" "${redeemscript}" "${pubkey}" "'"
    echo "prepare splitter tx :"
    printf '%s %s %s{"changePosition":1,"includeWatching":true}%s\n\n' "${clientname_cli} fundrawtransaction" "${taint_tx}" "'" "'"
}
tainter_mkimport "$1" "$2"
