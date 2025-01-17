#!/bin/bash
# Author: lidem
# Version: 1.0.0

echo "开始部署网络测试服务..."

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 1. 检查并安装 Nginx
if ! command -v nginx &> /dev/null; then
    echo "未检测到 Nginx，开始安装..."
    apt update
    apt install -y nginx
    if [ $? -ne 0 ]; then
        echo "❌ Nginx 安装失败"
        exit 1
    fi
    echo "✅ Nginx 安装成功"
fi

# 2. 确保必要的目录存在
echo "创建必要的目录..."
mkdir -p /etc/nginx/conf.d
mkdir -p /var/www/netprobe

# 3. 停止 Nginx（如果正在运行）
echo "停止 Nginx 服务..."
systemctl stop nginx || true

# 4. 清理旧配置和文件
echo "清理旧配置..."
rm -f /etc/nginx/conf.d/speedtest.conf
rm -f /etc/nginx/conf.d/netprobe.conf
rm -rf /var/www/speedtest

# 5. 生成测试文件
echo "生成测试文件..."
dd if=/dev/urandom of=/var/www/netprobe/16k bs=16K count=1 status=none
dd if=/dev/urandom of=/var/www/netprobe/64k bs=64K count=1 status=none
dd if=/dev/urandom of=/var/www/netprobe/512k bs=512K count=1 status=none
dd if=/dev/urandom of=/var/www/netprobe/1m bs=1M count=1 status=none

# 6. 设置正确的权限
echo "设置文件权限..."
chown -R www-data:www-data /var/www/netprobe
chmod 644 /var/www/netprobe/*

# 7. 创建 Nginx 配置
echo "创建 Nginx 配置..."
cat > /etc/nginx/conf.d/netprobe.conf << 'EOL'
server {
    listen 9999;
    access_log off;
    
    # 延迟测试 - 空响应
    location = / {
        add_header Content-Type text/plain;
        add_header Cache-Control no-store;
        return 200 "";
    }

    # 16KB 极小文件测试
    location = /tiny {
        alias /var/www/netprobe/16k;
        add_header Content-Type application/octet-stream;
        add_header Cache-Control no-store;
    }

    # 64KB 小文件测试
    location = /small {
        alias /var/www/netprobe/64k;
        add_header Content-Type application/octet-stream;
        add_header Cache-Control no-store;
    }

    # 512KB 中等文件测试
    location = /medium {
        alias /var/www/netprobe/512k;
        add_header Content-Type application/octet-stream;
        add_header Cache-Control no-store;
    }

    # 1MB 大文件测试
    location = /large {
        alias /var/www/netprobe/1m;
        add_header Content-Type application/octet-stream;
        add_header Cache-Control no-store;
    }

    # 状态页面
    location = /status {
        add_header Content-Type text/html;
        return 200 '
        <!DOCTYPE html>
        <html>
        <head>
            <title>Network Probe Status</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .endpoint { margin: 20px 0; padding: 10px; background: #f5f5f5; }
                .desc { color: #666; font-size: 0.9em; }
            </style>
        </head>
        <body>
            <h1>Network Probe Endpoints</h1>
            <div class="endpoint">
                <h3>Latency Test:</h3>
                <code>/</code>
                <div class="desc">Empty response (200 OK)</div>
            </div>
            <div class="endpoint">
                <h3>Bandwidth Tests:</h3>
                <code>/tiny</code> - 16KB file<br>
                <code>/small</code> - 64KB file<br>
                <code>/medium</code> - 512KB file<br>
                <code>/large</code> - 1MB file
            </div>
        </body>
        </html>
        ';
    }
}
EOL

# 8. 测试 Nginx 配置
echo "测试 Nginx 配置..."
nginx -t

if [ $? -eq 0 ]; then
    # 9. 启动 Nginx
    echo "启动 Nginx 服务..."
    systemctl start nginx
    
    # 10. 验证服务状态
    if systemctl is-active --quiet nginx; then
        echo -e "\n✅ 部署成功！"
        
        # 获取服务器 IP
        SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
        
        echo -e "\n可用测试端点："
        echo "1. 延迟测试:"
        echo "   http://${SERVER_IP}:9999/"
        echo -e "\n2. 带宽测试:"
        echo "   - 极小文件 (16KB): http://${SERVER_IP}:9999/tiny"
        echo "   - 小文件 (64KB):   http://${SERVER_IP}:9999/small"
        echo "   - 中等文件 (512KB): http://${SERVER_IP}:9999/medium"
        echo "   - 大文件 (1MB):    http://${SERVER_IP}:9999/large"
        echo -e "\n3. 状态页面:"
        echo "   http://${SERVER_IP}:9999/status"
        
        echo -e "\nSurge 配置示例："
        echo "1. 纯延迟测试:"
        echo "external-policy-modifier=\"test-url=http://${SERVER_IP}:9999/\""
        echo -e "\n2. 带宽测试 (根据网络环境选择):"
        echo "移动网络: external-policy-modifier=\"test-url=http://${SERVER_IP}:9999/tiny\""
        echo "家用网络: external-policy-modifier=\"test-url=http://${SERVER_IP}:9999/small\""
        echo "高速网络: external-policy-modifier=\"test-url=http://${SERVER_IP}:9999/medium\""
        echo "企业网络: external-policy-modifier=\"test-url=http://${SERVER_IP}:9999/large\""
        
        # 11. 本地测试
        echo -e "\n进行本地测试..."
        echo "延迟测试响应："
        curl -I http://localhost:9999/
        
        # 12. 显示文件大小信息
        echo -e "\n测试文件信息："
        ls -lh /var/www/netprobe/
        
        # 13. 检查端口是否开放
        echo -e "\n检查端口状态："
        if command -v netstat &> /dev/null; then
            netstat -tuln | grep 9999
        else
            ss -tuln | grep 9999
        fi
    else
        echo "❌ 部署失败：Nginx 服务未能正常启动"
        echo "请检查系统日志: journalctl -xe"
    fi
else
    echo "❌ 部署失败：Nginx 配置测试未通过"
fi
