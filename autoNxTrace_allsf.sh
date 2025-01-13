#!/bin/bash
# Author: lidem
# Version: 1.0.0
# Description: NextTrace 路由测试工具

# 日志函数
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# 检查并安装必要程序
check_dependencies() {
    log "INFO" "检查必要程序..."
    
    # 检查包管理器
    if command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    else
        log "ERROR" "未找到支持的包管理器(apt/yum/dnf)"
        exit 1
    fi
    
    # 检查必要程序
    local missing_pkgs=()
    for pkg in curl unzip ping dig; do
        if ! command -v $pkg &>/dev/null; then
            case $pkg in
                "dig") missing_pkgs+=("dnsutils") ;;
                *) missing_pkgs+=("$pkg") ;;
            esac
        fi
    done
    
    # 安装缺失的程序
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        log "INFO" "安装必要程序: ${missing_pkgs[*]}"
        sudo $PKG_MANAGER update
        sudo $PKG_MANAGER install -y "${missing_pkgs[@]}"
    fi
    
    # 安装 nexttrace
    if [ ! -f "/usr/local/bin/nexttrace" ]; then
        log "INFO" "安装 NextTrace..."
        curl nxtrace.org/nt | bash
    fi
}

# 初始化省份和运营商数据
init_carriers() {
    # 省份映射表 (序号=>省份名|缩写|英文名)
    declare -gA province_map
    province_map[1]="北京市|bj|beijing"
    province_map[2]="上海市|sh|shanghai"
    province_map[3]="天津市|tj|tianjin"
    province_map[4]="重庆市|cq|chongqing"
    province_map[5]="河北省|hb|hebei"
    province_map[6]="山西省|sx|shanxi"
    province_map[7]="辽宁省|ln|liaoning"
    province_map[8]="吉林省|jl|jilin"
    province_map[9]="黑龙江省|hlj|heilongjiang"
    province_map[10]="江苏省|js|jiangsu"
    province_map[11]="浙江省|zj|zhejiang"
    province_map[12]="安徽省|ah|anhui"
    province_map[13]="福建省|fj|fujian"
    province_map[14]="江西省|jx|jiangxi"
    province_map[15]="山东省|sd|shandong"
    province_map[16]="河南省|hn|henan"
    province_map[17]="湖北省|hub|hubei"
    province_map[18]="湖南省|hun|hunan"
    province_map[19]="广东省|gd|guangdong"
    province_map[20]="海南省|hi|hainan"
    province_map[21]="四川省|sc|sichuan"
    province_map[22]="贵州省|gz|guizhou"
    province_map[23]="云南省|yn|yunnan"
    province_map[24]="陕西省|shx|shaanxi"
    province_map[25]="甘肃省|gs|gansu"
    province_map[26]="青海省|qh|qinghai"
    province_map[27]="广西壮族自治区|gx|guangxi"
    province_map[28]="内蒙古自治区|nm|neimenggu"
    province_map[29]="西藏自治区|xz|xizang"
    province_map[30]="宁夏回族自治区|nx|ningxia"
    province_map[31]="新疆维吾尔自治区|xj|xinjiang"
    
    # 联通测试IP (省份=>IP)
    declare -gA province_cu
    province_cu["北京市"]="bj-cu-v4.ip.zstaticcdn.com"
    province_cu["上海市"]="sh-cu-v4.ip.zstaticcdn.com"
    province_cu["天津市"]="tj-cu-v4.ip.zstaticcdn.com"
    province_cu["重庆市"]="cq-cu-v4.ip.zstaticcdn.com"
    province_cu["河北省"]="he-cu-v4.ip.zstaticcdn.com"
    province_cu["山西省"]="sx-cu-v4.ip.zstaticcdn.com"
    province_cu["辽宁省"]="ln-cu-v4.ip.zstaticcdn.com"
    province_cu["吉林省"]="jl-cu-v4.ip.zstaticcdn.com"
    province_cu["黑龙江省"]="hl-cu-v4.ip.zstaticcdn.com"
    province_cu["江苏省"]="js-cu-v4.ip.zstaticcdn.com"
    province_cu["浙江省"]="zj-cu-v4.ip.zstaticcdn.com"
    province_cu["安徽省"]="ah-cu-v4.ip.zstaticcdn.com"
    province_cu["福建省"]="fj-cu-v4.ip.zstaticcdn.com"
    province_cu["江西省"]="jx-cu-v4.ip.zstaticcdn.com"
    province_cu["山东省"]="sd-cu-v4.ip.zstaticcdn.com"
    province_cu["河南省"]="ha-cu-v4.ip.zstaticcdn.com"
    province_cu["湖北省"]="hb-cu-v4.ip.zstaticcdn.com"
    province_cu["湖南省"]="hn-cu-v4.ip.zstaticcdn.com"
    province_cu["广东省"]="gd-cu-v4.ip.zstaticcdn.com"
    province_cu["海南省"]="hi-cu-v4.ip.zstaticcdn.com"
    province_cu["四川省"]="sc-cu-v4.ip.zstaticcdn.com"
    province_cu["贵州省"]="gz-cu-v4.ip.zstaticcdn.com"
    province_cu["云南省"]="yn-cu-v4.ip.zstaticcdn.com"
    province_cu["陕西省"]="sn-cu-v4.ip.zstaticcdn.com"
    province_cu["甘肃省"]="gs-cu-v4.ip.zstaticcdn.com"
    province_cu["青海省"]="qh-cu-v4.ip.zstaticcdn.com"
    province_cu["广西壮族自治区"]="gx-cu-v4.ip.zstaticcdn.com"
    province_cu["内蒙古自治区"]="nm-cu-v4.ip.zstaticcdn.com"
    province_cu["西藏自治区"]="xz-cu-v4.ip.zstaticcdn.com"
    province_cu["宁夏回族自治区"]="nx-cu-v4.ip.zstaticcdn.com"
    province_cu["新疆维吾尔自治区"]="xj-cu-v4.ip.zstaticcdn.com"
    
    # 移动测试IP (省份=>IP)
    declare -gA province_cm
    province_cm["北京市"]="bj-cm-v4.ip.zstaticcdn.com"
    province_cm["上海市"]="sh-cm-v4.ip.zstaticcdn.com"
    province_cm["天津市"]="tj-cm-v4.ip.zstaticcdn.com"
    province_cm["重庆市"]="cq-cm-v4.ip.zstaticcdn.com"
    province_cm["河北省"]="he-cm-v4.ip.zstaticcdn.com"
    province_cm["山西省"]="sx-cm-v4.ip.zstaticcdn.com"
    province_cm["辽宁省"]="ln-cm-v4.ip.zstaticcdn.com"
    province_cm["吉林省"]="jl-cm-v4.ip.zstaticcdn.com"
    province_cm["黑龙江省"]="hl-cm-v4.ip.zstaticcdn.com"
    province_cm["江苏省"]="js-cm-v4.ip.zstaticcdn.com"
    province_cm["浙江省"]="zj-cm-v4.ip.zstaticcdn.com"
    province_cm["安徽省"]="ah-cm-v4.ip.zstaticcdn.com"
    province_cm["福建省"]="fj-cm-v4.ip.zstaticcdn.com"
    province_cm["江西省"]="jx-cm-v4.ip.zstaticcdn.com"
    province_cm["山东省"]="sd-cm-v4.ip.zstaticcdn.com"
    province_cm["河南省"]="ha-cm-v4.ip.zstaticcdn.com"
    province_cm["湖北省"]="hb-cm-v4.ip.zstaticcdn.com"
    province_cm["湖南省"]="hn-cm-v4.ip.zstaticcdn.com"
    province_cm["广东省"]="gd-cm-v4.ip.zstaticcdn.com"
    province_cm["海南省"]="hi-cm-v4.ip.zstaticcdn.com"
    province_cm["四川省"]="sc-cm-v4.ip.zstaticcdn.com"
    province_cm["贵州省"]="gz-cm-v4.ip.zstaticcdn.com"
    province_cm["云南省"]="yn-cm-v4.ip.zstaticcdn.com"
    province_cm["陕西省"]="sn-cm-v4.ip.zstaticcdn.com"
    province_cm["甘肃省"]="gs-cm-v4.ip.zstaticcdn.com"
    province_cm["青海省"]="qh-cm-v4.ip.zstaticcdn.com"
    province_cm["广西壮族自治区"]="gx-cm-v4.ip.zstaticcdn.com"
    province_cm["内蒙古自治区"]="nm-cm-v4.ip.zstaticcdn.com"
    province_cm["西藏自治区"]="xz-cm-v4.ip.zstaticcdn.com"
    province_cm["宁夏回族自治区"]="nx-cm-v4.ip.zstaticcdn.com"
    province_cm["新疆维吾尔自治区"]="xj-cm-v4.ip.zstaticcdn.com"
    
    # 电信测试IP (省份=>IP)
    declare -gA province_ct
    province_ct["北京市"]="bj-ct-v4.ip.zstaticcdn.com"
    province_ct["上海市"]="sh-ct-v4.ip.zstaticcdn.com"
    province_ct["天津市"]="tj-ct-v4.ip.zstaticcdn.com"
    province_ct["重庆市"]="cq-ct-v4.ip.zstaticcdn.com"
    province_ct["河北省"]="he-ct-v4.ip.zstaticcdn.com"
    province_ct["山西省"]="sx-ct-v4.ip.zstaticcdn.com"
    province_ct["辽宁省"]="ln-ct-v4.ip.zstaticcdn.com"
    province_ct["吉林省"]="jl-ct-v4.ip.zstaticcdn.com"
    province_ct["黑龙江省"]="hl-ct-v4.ip.zstaticcdn.com"
    province_ct["江苏省"]="js-ct-v4.ip.zstaticcdn.com"
    province_ct["浙江省"]="zj-ct-v4.ip.zstaticcdn.com"
    province_ct["安徽省"]="ah-ct-v4.ip.zstaticcdn.com"
    province_ct["福建省"]="fj-ct-v4.ip.zstaticcdn.com"
    province_ct["江西省"]="jx-ct-v4.ip.zstaticcdn.com"
    province_ct["山东省"]="sd-ct-v4.ip.zstaticcdn.com"
    province_ct["河南省"]="ha-ct-v4.ip.zstaticcdn.com"
    province_ct["湖北省"]="hb-ct-v4.ip.zstaticcdn.com"
    province_ct["湖南省"]="hn-ct-v4.ip.zstaticcdn.com"
    province_ct["广东省"]="gd-ct-v4.ip.zstaticcdn.com"
    province_ct["海南省"]="hi-ct-v4.ip.zstaticcdn.com"
    province_ct["四川省"]="sc-ct-v4.ip.zstaticcdn.com"
    province_ct["贵州省"]="gz-ct-v4.ip.zstaticcdn.com"
    province_ct["云南省"]="yn-ct-v4.ip.zstaticcdn.com"
    province_ct["陕西省"]="sn-ct-v4.ip.zstaticcdn.com"
    province_ct["甘肃省"]="gs-ct-v4.ip.zstaticcdn.com"
    province_ct["青海省"]="qh-ct-v4.ip.zstaticcdn.com"
    province_ct["广西壮族自治区"]="gx-ct-v4.ip.zstaticcdn.com"
    province_ct["内蒙古自治区"]="nm-ct-v4.ip.zstaticcdn.com"
    province_ct["西藏自治区"]="xz-ct-v4.ip.zstaticcdn.com"
    province_ct["宁夏回族自治区"]="nx-ct-v4.ip.zstaticcdn.com"
    province_ct["新疆维吾尔自治区"]="xj-ct-v4.ip.zstaticcdn.com"
    
    # 初始化汇总数组
    declare -gA summary_cu
    declare -gA summary_cm
    declare -gA summary_ct
}

# 修改欢迎信息
show_welcome() {
    clear
    echo "============================================"
    echo "      回程路由测试工具（大陆各省）        "
    echo "============================================"
    echo "作者: lidem"
    echo "版本: 1.0.0"
    echo "----------------------------------------"
    echo "功能介绍："
    echo "1. 支持测试电信/联通/移动三大运营商线路"
    echo "2. 自动识别线路类型(CN2/GIA/AS4837等)"
    echo "3. 显示详细的路由跟踪信息"
    echo "4. 测试回程延迟"
    echo "5. 生成完整测试报告"
    echo "----------------------------------------"
    echo "提示：测试过程可能需要几分钟时间"
    echo "============================================"
    echo ""
}

# 显示省份选择菜单
show_province_menu() {
    echo "可测试的省份列表："
    echo "----------------------------------------"
    printf "%-6s|%-6s|%-s\n" "序号" "缩写" "省份"
    echo "----------------------------------------"
    
    # 对省份按序号排序
    local sorted_nums=($(echo "${!province_map[@]}" | tr ' ' '\n' | sort -n))
    for num in "${sorted_nums[@]}"; do
        IFS='|' read -r name abbr eng <<< "${province_map[$num]}"
        printf "%-6s|%-6s|%-s\n" "$num" "$abbr" "$name"
    done
    
    echo "----------------------------------------"
    echo "输入方式："
    echo "1. 序号(如: 1 2 3)"
    echo "2. 英文缩写(如: bj sh gz)"
    echo "3. 输入'all'测试所有省份"
    echo "----------------------------------------"
}

# 保存测试结果
save_results() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename="nexttrace_results_${timestamp}.txt"
    
    {
        echo "============================================"
        echo "           NextTrace 测试报告"
        echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "============================================"
        echo ""
        echo "测试汇总结果："
        echo "----------------------------------------"
        echo "联通线路汇总："
        for province in "${!summary_cu[@]}"; do
            if [ ! -z "${summary_cu[$province]}" ]; then
                IFS='|' read -r carrier quality latency as_path <<< "${summary_cu[$province]}"
                if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                    printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                    if [ ! -z "$as_path" ]; then
                        printf "           AS路径: %s\n" "$as_path"
                    fi
                fi
            fi
        done
        
        echo "----------------------------------------"
        echo "移动线路汇总："
        for province in "${!summary_cm[@]}"; do
            if [ ! -z "${summary_cm[$province]}" ]; then
                IFS='|' read -r carrier quality latency as_path <<< "${summary_cm[$province]}"
                if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                    printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                    if [ ! -z "$as_path" ]; then
                        printf "           AS路径: %s\n" "$as_path"
                    fi
                fi
            fi
        done
        
        echo "----------------------------------------"
        echo "电信线路汇总："
        for province in "${!summary_ct[@]}"; do
            if [ ! -z "${summary_ct[$province]}" ]; then
                IFS='|' read -r carrier quality latency as_path <<< "${summary_ct[$province]}"
                if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                    printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                    if [ ! -z "$as_path" ]; then
                        printf "           AS路径: %s\n" "$as_path"
                    fi
                fi
            fi
        done
        echo "============================================"
    } > "$filename"
    
    log "INFO" "测试结果已保存到: $filename"
}

# 解析用户输入
parse_input() {
    local input="$1"
    local provinces=""
    
    # 如果输入 all，返回所有省份
    if [ "$input" == "all" ]; then
        for num in "${!province_map[@]}"; do
            IFS='|' read -r name _ _ <<< "${province_map[$num]}"
            provinces="$provinces $name"
        done
        echo "$provinces"
        return
    fi
    
    # 处理序号或缩写输入
    for item in $input; do
        if [[ "$item" =~ ^[0-9]+$ ]]; then
            # 序号输入
            if [ -n "${province_map[$item]}" ]; then
                IFS='|' read -r name _ _ <<< "${province_map[$item]}"
                provinces="$provinces $name"
            fi
        else
            # 缩写输入
            for num in "${!province_map[@]}"; do
                IFS='|' read -r name abbr _ <<< "${province_map[$num]}"
                if [ "$abbr" == "$item" ]; then
                    provinces="$provinces $name"
                    break
                fi
            done
        fi
    done
    
    echo "$provinces"
}

# 换行函数
next() {
    echo "----------------------------------------------------------------------"
}

# 测试特定运营商
test_carrier() {
    local province="$1"
    local carrier="$2"
    local ip="$3"
    local carrier_name
    local route_info=("未知线路" "无法获取线路信息") # 初始化默认值
    local avg_latency="0"
    local as_path=""
    
    case $carrier in
        "cu") carrier_name="联通";;
        "cm") carrier_name="移动";;
        "ct") carrier_name="电信";;
    esac
    
    # 设置输出不缓存
    exec 1>&1
    
    log "DEBUG" "======================================"
    log "DEBUG" "开始测试: ${province} ${carrier_name}"
    log "DEBUG" "测试目标: ${ip}"
    
    # 检查IP是否为空
    if [ -z "$ip" ]; then
        log "ERROR" "无法获取 ${province} 的 ${carrier_name} 测试IP"
        echo "${carrier_name}|未知线路|0"
        return 1
    fi
    
    # 先解析IP地址
    log "DEBUG" "正在解析域名..."
    local resolved_ip=$(dig +short $ip | head -n1)
    if [ -z "$resolved_ip" ]; then
        log "ERROR" "无法解析域名 ${ip}"
        echo "${carrier_name}|无法解析域名|0"
        return 1
    fi
    
    log "INFO" "域名 ${ip} 解析为: ${resolved_ip}"
    
    # 获取完整AS路径 - 添加延迟避免API限制
    log "DEBUG" "正在执行: nexttrace -r ${ip}"
    echo "----------------------------------------"
    sleep 2 # 添加延迟
    result=$(nexttrace -r $ip 2>&1)
    if [[ $result =~ "请求次数超限" ]]; then
        log "WARN" "API请求次数超限，等待10秒后重试..."
        sleep 10
        result=$(nexttrace -T -r $ip 2>&1)
    fi
    echo "$result" | tee /dev/tty  # 显示路由追踪结果
    echo "----------------------------------------"
    
    # 提取AS路径
    as_path=$(echo "$result" | grep -oE 'AS[0-9]+' | sort -u | tr '\n' ' ')
    log "DEBUG" "提取的AS路径: $as_path"
    
    if [ ! -z "$as_path" ]; then
        log "INFO" "AS路径: $as_path"
        readarray -t route_info < <(check_route_quality "$as_path")
        if [ ${#route_info[@]} -lt 2 ]; then
            route_info=("未知线路" "无法获取线路信息")
        fi
        log "INFO" "线路类型: ${route_info[0]}"
        log "INFO" "详细信息: ${route_info[1]}"
    else
        log "ERROR" "无法获取任何AS信息"
        route_info=("未知线路" "无法获取线路信息")
    fi
    
    # 测试回程延迟
    log "DEBUG" "正在测试回程延迟..."
    echo "----------------------------------------"
    ping -c 4 $ip | tee /dev/tty
    echo "----------------------------------------"
    local ping_result=$(ping -c 4 $ip 2>&1)
    
    avg_latency=$(echo "$ping_result" | tail -n1 | awk -F '/' '{print $5}')
    if [ ! -z "$avg_latency" ]; then
        log "INFO" "回程平均延迟: ${avg_latency}ms"
    else
        log "WARN" "无法获取延迟信息"
        avg_latency="0"
    fi
    
    # 执行路由追踪 - 添加延迟避免API限制
    log "DEBUG" "开始路由追踪..."
    echo "----------------------------------------"
    sleep 2 # 添加延迟
    result=$(nexttrace -M $ip 2>&1)
    if [[ $result =~ "请求次数超限" ]]; then
        log "WARN" "API请求次数超限，等待10秒后重试..."
        sleep 10
        result=$(nexttrace -T -M $ip 2>&1)
    fi
    echo "$result" | tee /dev/tty  # 显示路由追踪结果
    echo "----------------------------------------"
    log "DEBUG" "======================================"
    
    # 返回汇总信息（添加AS路径）
    echo "${carrier_name}|${route_info[0]}|${avg_latency}|${as_path}"
}

# 修改check_route_quality函数，增加更多的路由判断
check_route_quality() {
    local as_path="$1"
    local quality="未知线路"
    local detail="无法获取线路信息"
    
    # 联通线路判断
    if [[ $as_path =~ "AS4837" && $as_path =~ "AS10099" ]]; then
        quality="联通169+CUG - 优质线路"
        detail="联通高端线路组合(AS4837+AS10099)"
    elif [[ $as_path =~ "AS4837" ]]; then
        quality="联通169骨干网 - 普通线路"
        detail="走联通169骨干网，AS4837为主"
    elif [[ $as_path =~ "AS9929" ]]; then
        quality="联通A网 - 高端线路"
        detail="联通精品网络，优于169"
    fi
    
    # 移动线路判断
    if [[ $as_path =~ "AS58453" ]]; then
        quality="移动CMI - 优质线路"
        detail="移动国际精品网络，优于普通骨干网"
    elif [[ $as_path =~ "AS9808" ]]; then
        quality="移动骨干网 - 普通线路"
        detail="走移动骨干网，AS9808为主"
    elif [[ $as_path =~ "AS56040" ]]; then
        quality="移动CMNET - 普通线路"
        detail="走移动骨干网，AS56040为主"
    fi
    
    # 电信线路判断
    if [[ $as_path =~ "AS4809" ]]; then
        quality="电信CN2 - 优质线路"
        detail="电信CN2网络，优于163骨干网"
    elif [[ $as_path =~ "AS4134" ]]; then
        quality="电信163骨干网 - 普通线路"
        detail="走163骨干网，全程不经过CN2，202.97.*.*为主"
    elif [[ $as_path =~ "AS4812" ]]; then
        quality="电信163骨干网 - 普通线路"
        detail="走163骨干网，AS4812为主"
    fi
    
    echo "$quality"
    echo "$detail"
}

# 主程序
main() {
    # 检查依赖
    check_dependencies
    
    # 显示欢迎信息
    show_welcome
    
    # 初始化运营商数据
    init_carriers
    
    # 显示省份菜单
    show_province_menu
    
    # 获取用户输入
    read -p "请输入要测试的省份(序号/缩写/all): " input
    selected_provinces=$(parse_input "$input")
    
    # 开始测试
    for province in $selected_provinces; do
        log "INFO" "开始测试省份: $province"
        next
        
        # 测试联通
        log "INFO" "测试联通线路..."
        result=$(test_carrier "$province" "cu" "${province_cu[$province]}" | tail -n1)
        log "DEBUG" "联通测试结果: $result"
        if [ ! -z "$result" ]; then
            summary_cu[$province]="$result"
        fi
        
        # 测试移动
        log "INFO" "测试移动线路..."
        result=$(test_carrier "$province" "cm" "${province_cm[$province]}" | tail -n1)
        log "DEBUG" "移动测试结果: $result"
        if [ ! -z "$result" ]; then
            summary_cm[$province]="$result"
        fi
        
        # 测试电信
        log "INFO" "测试电信线路..."
        result=$(test_carrier "$province" "ct" "${province_ct[$province]}" | tail -n1)
        log "DEBUG" "电信测试结果: $result"
        if [ ! -z "$result" ]; then
            summary_ct[$province]="$result"
        fi
        
        next
    done
    
    # 输出汇总结果
    log "INFO" "测试完成，输出汇总结果"
    echo "============================================"
    echo "测试汇总结果："
    echo "----------------------------------------"
    echo "联通线路汇总："
    for province in "${!summary_cu[@]}"; do
        if [ ! -z "${summary_cu[$province]}" ]; then
            IFS='|' read -r carrier quality latency as_path <<< "${summary_cu[$province]}"
            if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                if [ ! -z "$as_path" ]; then
                    printf "           AS路径: %s\n" "$as_path"
                fi
            fi
        fi
    done
    
    echo "----------------------------------------"
    echo "移动线路汇总："
    for province in "${!summary_cm[@]}"; do
        if [ ! -z "${summary_cm[$province]}" ]; then
            IFS='|' read -r carrier quality latency as_path <<< "${summary_cm[$province]}"
            if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                if [ ! -z "$as_path" ]; then
                    printf "           AS路径: %s\n" "$as_path"
                fi
            fi
        fi
    done
    
    echo "----------------------------------------"
    echo "电信线路汇总："
    for province in "${!summary_ct[@]}"; do
        if [ ! -z "${summary_ct[$province]}" ]; then
            IFS='|' read -r carrier quality latency as_path <<< "${summary_ct[$province]}"
            if [ ! -z "$quality" ] && [ ! -z "$latency" ]; then
                printf "%-10s - %-40s (延迟: %sms)\n" "$province" "$quality" "$latency"
                if [ ! -z "$as_path" ]; then
                    printf "           AS路径: %s\n" "$as_path"
                fi
            fi
        fi
    done
    echo "============================================"
    
    # 询问是否保存结果
    echo ""
    read -p "是否保存测试结果到文件? (y/n): " save_choice
    if [[ $save_choice =~ ^[Yy]$ ]]; then
        save_results
    fi
}

# 执行主程序
main