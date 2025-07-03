#!/usr/bin/env bash

set -e

rm -rf clash
git clone https://github.com/wnlen/clash-for-linux.git clash

cd clash

WORK_DIR=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)

cp -a ${WORK_DIR}/../clash-config-private.yaml ${WORK_DIR}/conf/config.yaml
sed -i "s#^external-ui: dashboard/public#external-ui: ${WORK_DIR}/dashboard/public#g" ${WORK_DIR}/conf/config.yaml

chmod +x ${WORK_DIR}/bin/*

sudo cat > /etc/systemd/system/clash.service <<EOF
[Unit]
Description=Clash Meta Service
After=network.target nss-lookup.target

[Service]
ExecStart=${WORK_DIR}/bin/clash-linux-amd64 -d ${WORK_DIR}/conf
StandardOutput=append:${WORK_DIR}/logs/clash.log
StandardError=append:${WORK_DIR}/logs/clash-error.log
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable clash
sudo systemctl restart clash

echo ''
echo -e "Clash Dashboard: http://<ip>:18890/ui"
echo ''

# 添加环境变量(root权限)
sudo cat>/etc/profile.d/clash.sh<<EOF
# 开启系统代理
function proxy_on() {
	export http_proxy=http://127.0.0.1:18888
	export https_proxy=http://127.0.0.1:18888
	export no_proxy=127.0.0.1,localhost
  export HTTP_PROXY=http://127.0.0.1:18888
  export HTTPS_PROXY=http://127.0.0.1:18888
 	export NO_PROXY=127.0.0.1,localhost
	echo -e "\033[32m[√] Proxy opened\033[0m"
}

# 关闭系统代理
function proxy_off(){
	unset http_proxy
	unset https_proxy
	unset no_proxy
  unset HTTP_PROXY
	unset HTTPS_PROXY
	unset NO_PROXY
	echo -e "\033[31m[×] Proxy closed\033[0m"
}
EOF

echo -e "Please execute the following command to load environment variables: source /etc/profile.d/clash.sh"
echo -e "To enable the system proxy, please execute: proxy_on"
echo -e "To disable the system proxy, please execute: proxy_off"
