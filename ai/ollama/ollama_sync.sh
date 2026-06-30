#!/bin/bash

# ==========================================
# Ollama 模型同步管理脚本
# ==========================================

CONFIG_FILE="ollama_models.conf"

# 检查 Ollama 是否安装及运行
function check_ollama() {
	if ! command -v ollama &>/dev/null; then
		echo "错误: 未找到 ollama 命令，请先安装 Ollama。"
		exit 1
	fi
	if ! ollama list &>/dev/null; then
		echo "错误: Ollama 服务未运行，或无法连接。"
		exit 1
	fi
}

# 模式 1：将系统已存模型更新到配置文件 (Save)
function save_to_config() {
	# 获取系统当前模型（去掉第一行表头）
	local models=$(ollama list | tail -n +2)

	# 若系统没有模型
	if [[ -z $(echo "$models" | tr -d '[:space:]') ]]; then
		echo "当前系统中不存在任何 Ollama 模型。"
		if [[ ! -f "$CONFIG_FILE" ]]; then
			echo "未找到 $CONFIG_FILE，且系统无模型，不做任何操作。"
		fi
		return
	fi

	# 若不存在配置文件，则生成非空配置文件并带上表头注释
	if [[ ! -f "$CONFIG_FILE" ]]; then
		echo "正在创建配置文件 $CONFIG_FILE ..."
		echo "# NAME               ID              SIZE      MODIFIED" >"$CONFIG_FILE"
		echo "$models" >>"$CONFIG_FILE"
		echo "✅ 已成功生成配置文件并写入现有模型。"
		return
	fi

	# 若配置文件已存在，则只追加配置文件中没有的新模型
	echo "正在将系统新模型追加到 $CONFIG_FILE ..."
	local temp_file=$(mktemp)
	cp "$CONFIG_FILE" "$temp_file"

	echo "$models" | while IFS= read -r line; do
		local name=$(echo "$line" | awk '{print $1}')
		# 检查配置文件中是否已存在该模型名称（包括被注释的行）
		if ! grep -Eq "^[[:space:]#]*${name}([[:space:]]|$)" "$CONFIG_FILE"; then
			echo "追加新模型: $name"
			echo "$line" >>"$temp_file"
		fi
	done
	mv "$temp_file" "$CONFIG_FILE"
	echo "✅ 配置文件更新完成。"
}

# 模式 2：根据配置文件增删模型，并自动补全信息 (Apply)
function apply_from_config() {
	# 防呆逻辑：若没有配置文件，则不能执行，避免清空系统模型
	if [[ ! -f "$CONFIG_FILE" ]]; then
		echo "错误: 未找到 $CONFIG_FILE ！已终止操作，避免误清空系统模型。"
		exit 1
	fi

	# 读取配置文件中期望的模型（过滤空行和注释行，提取第一列）
	local desired_models=$(awk '/^[[:space:]]*[^#[:space:]]/ {print $1}' "$CONFIG_FILE")
	# 读取系统目前的模型
	local current_models=$(ollama list | tail -n +2 | awk 'NF>0 {print $1}')

	# 1. 增：Pull 缺失的模型
	for d_model in $desired_models; do
		if ! echo "$current_models" | grep -Fqxw "$d_model"; then
			echo "📥 正在下载缺失的模型: $d_model ..."
			if ! ollama pull "$d_model"; then
				echo "❌ 错误: 下载 $d_model 失败！"
			fi
		fi
	done

	# 2. 删：Rm 多余的模型（系统中存在，但在配置文件中被注释或不存在）
	for c_model in $current_models; do
		if ! echo "$desired_models" | grep -Fqxw "$c_model"; then
			echo "🗑️ 正在删除多余的模型: $c_model ..."
			ollama rm "$c_model"
		fi
	done

	# 3. 自动补全：更新配置文件，补全 SIZE 等信息，同时保留用户的注释和排版
	echo "🔄 正在自动补全 $CONFIG_FILE 中的模型信息..."
	local temp_file=$(mktemp)
	# 重新获取最新的系统模型列表，以防刚下载的模型信息不全
	local full_list=$(ollama list | tail -n +2)

	while IFS= read -r line || [[ -n "$line" ]]; do
		# 检查是否是空行或注释行
		if [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
			echo "$line" >>"$temp_file"
		else
			local m_name=$(echo "$line" | awk '{print $1}')
			# 从最新系统列表中精准匹配该模型名称所在的完整行
			local full_info=$(echo "$full_list" | awk -v name="$m_name" '$1 == name {print $0}')
			if [[ -n "$full_info" ]]; then
				echo "$full_info" >>"$temp_file" # 写入完整信息
			else
				echo "$line" >>"$temp_file" # 降级策略，写入原始行
			fi
		fi
	done <"$CONFIG_FILE"

	mv "$temp_file" "$CONFIG_FILE"
	echo "✅ 模型同步及配置文件自动补全已完成！"
}

# 主程序路由
check_ollama

case "$1" in
save)
	save_to_config
	;;
apply)
	apply_from_config
	;;
*)
	echo "使用说明: $0 {save|apply}"
	echo "  save  : 将当前系统中的模型保存/更新到 $CONFIG_FILE 中。"
	echo "  apply : 根据 $CONFIG_FILE 增删系统模型，同步完成后自动补全配置信息。"
	exit 1
	;;
esac
