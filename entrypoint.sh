#!/usr/bin/env bash

# 设置各变量
APIHOST=${APIHOST}
APIKEY=${APIKEY}
NID=${NID}

NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

ARGO_TOKEN=${ARGO_TOKEN}
ARGO_DOMAIN=${ARGO_DOMAIN}

generate_config() {
  cat > config.yml << EOF
Log:
  Level: none
  AccessPath:
  ErrorPath:
DnsConfigPath:
ConnetionConfig:
  Handshake: 4
  ConnIdle: 10
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  -
    PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "${APIHOST}"
      ApiKey: "${APIKEY}"
      NodeID: ${NID}
      NodeType: V2ray
      Timeout: 30
      EnableVless: false
      EnableXTLS: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      CertConfig:
        CertMode: none
EOF
EOF
}

generate_argo() {
  cat > argo.sh << ABC
#!/usr/bin/env bash

ARGO_TOKEN=${ARGO_TOKEN}
ARGO_DOMAIN=${ARGO_DOMAIN}

export_list() {
  [[ -z "\${ARGO_TOKEN}" || -z "\${ARGO_DOMAIN}" ]] && ARGO_DOMAIN=\$(cat argo.log | grep -oE "https://.*[a-z]+cloudflare.com" | sed "s#https://##" | tail -n 1)
  VMESS="{ \"v\": \"2\", \"ps\": \"Argo-Vmess\", \"add\": \"www.digitalocean.com\", \"port\": \"443\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\${ARGO_DOMAIN}\", \"path\": \"/${WSPATH}-vmess\", \"tls\": \"tls\", \"sni\": \"\${ARGO_DOMAIN}\", \"alpn\": \"\" }"

  cat > list << EOF
*******************************************
NID  ==> ${NID}
ARGO ==> \${ARGO_DOMAIN}
NID  ==> ${NID}
*******************************************
EOF
  cat list
}

export_list
ABC
}

generate_nezha() {
  cat > nezha.sh << EOF
#!/usr/bin/env bash

# 哪吒的三个参数
NEZHA_SERVER=${NEZHA_SERVER}
NEZHA_PORT=${NEZHA_PORT}
NEZHA_KEY=${NEZHA_KEY}

# 检测是否已运行
check_run() {
  [[ \$(pgrep -laf nezha-agent) ]] && echo "哪吒客户端正在运行中" && exit
}

# 三个变量不全则不安装哪吒客户端
check_variable() {
  [[ -z "\${NEZHA_SERVER}" || -z "\${NEZHA_PORT}" || -z "\${NEZHA_KEY}" ]] && exit
}

# 下载最新版本 Nezha Agent
download_agent() {
  if [ ! -e nezha-agent ]; then
    URL=\$(wget -qO- -4 "https://api.github.com/repos/naiba/nezha/releases/latest" | grep -o "https.*linux_amd64.zip")
    wget -t 2 -T 10 -N \${URL}
    unzip -qod ./ nezha-agent_linux_amd64.zip && rm -f nezha-agent_linux_amd64.zip
  fi
}

check_run
check_variable
download_agent
EOF
}

generate_pm2_file() {
  [[ -z "${ARGO_TOKEN}" || -z "${ARGO_DOMAIN}" ]] && ARGO_ARGS="tunnel --url http://localhost:8080 --no-autoupdate" || ARGO_ARGS="tunnel --no-autoupdate run --token ${ARGO_TOKEN}"
  if [[ -z "${NEZHA_SERVER}" || -z "${NEZHA_PORT}" || -z "${NEZHA_KEY}" ]]; then
    cat > ecosystem.config.js << EOF
  module.exports = {
  "apps":[
      {
          "name":"web",
          "script":"/app/web.js"
      },
      {
          "name":"argo",
          "script":"cloudflared",
          "args":"${ARGO_ARGS}",
          "error_file":"/app/argo.log"
      }
  ]
}
EOF
  else
    cat > ecosystem.config.js << EOF
module.exports = {
  "apps":[
      {
          "name":"web",
          "script":"/app/web.js"
      },
      {
          "name":"argo",
          "script":"cloudflared",
          "args":"${ARGO_ARGS}",
          "error_file":"/app/argo.log"
      },
      {
          "name":"nezha",
          "script":"/app/nezha-agent",
          "args":"-s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY}"
      }
  ]
}
EOF
  fi
}

generate_config
generate_argo
generate_nezha
generate_pm2_file
[ -e nezha.sh ] && bash nezha.sh
[ -e argo.sh ] && bash argo.sh
pm2 start