#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -u <url> -n <number_of_requests> [-h <custom_headers>] [-c <tor_config>]"
    echo "  -u  Target URL"
    echo "  -n  Number of requests"
    echo "  -h  Custom headers (optional) in 'key:value' format, separated by commas"
    echo "  -c  Custom Tor configuration file (optional, default: /etc/tor/torrc)"
    exit 1
}

# Default Tor configuration file and proxy settings
tor_config="/etc/tor/torrc"
tor_proxy="127.0.0.1:9050"

# Parse command-line arguments
while getopts ":u:n:h:c:" opt; do
    case $opt in
        u) url="$OPTARG" ;;
        n) num_requests="$OPTARG" ;;
        h) headers="$OPTARG" ;;
        c) tor_config="$OPTARG" ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
if [ -z "$url" ] || [ -z "$num_requests" ]; then
    usage
fi

# Start Tor in the background if it's not running
if ! pgrep -x "tor" > /dev/null; then
    echo "Starting Tor..."
    tor -f "$tor_config" > /dev/null 2>&1 &
    sleep 5 # Wait for Tor to start
fi

# Split headers if provided
header_args=()
if [ -n "$headers" ]; then
    IFS=',' read -ra header_list <<< "$headers"
    for header in "${header_list[@]}"; do
        header_args+=("-H" "$header")
    done
fi

# Loop to send requests through Tor
for i in $(seq 1 "$num_requests"); do
    echo "Requesting through Tor (attempt $i)..."
    curl --socks5-hostname "$tor_proxy" "${header_args[@]}" "$url" -s -o /dev/null \
        && echo "Request succeeded (attempt $i)" \
        || echo "Request failed (attempt $i)"
    echo ""

    # Optionally restart Tor for a new identity
    echo "Requesting a new Tor identity..."
    pkill -HUP tor
    sleep 5
done

# Stop Tor after the requests are complete
echo "Stopping Tor..."
pkill tor
