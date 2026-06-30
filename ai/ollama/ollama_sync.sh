#!/bin/bash

# ==========================================
# Ollama 模型同步管理脚本 v2.0
# ==========================================

CONFIG_FILE="~/ollama_models.txt"

# 检查 Ollama 是否安装及运行
function check_ollama() {
	if ! command -v ollama &>/dev/null; then
		echo "❌ 错误: 未找到 ollama 命令，请先安装 Ollama。"
		exit 1
	fi
	if ! ollama list &>/dev/null; then
		echo "❌ 错误: Ollama 服务未运行，或无法连接。"
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
		echo "✅ 已成功生成配置文件，并写入以下现有模型："
		echo "$models" | awk '{print "  - "$1}'
		return
	fi

	# 若配置文件已存在，则只追加配置文件中没有的新模型
	echo "正在扫描系统新模型..."
	local temp_file=$(mktemp)
	cp "$CONFIG_FILE" "$temp_file"

	local added_models=()

	# 使用 Here-string 避免由于管道(pipe)产生的子 Shell 导致 added_models 变量丢失
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -z "$(echo "$line" | tr -d '[:space:]')" ]]; then continue; fi

		local name=$(echo "$line" | awk '{print $1}')
		# 检查配置文件中是否已存在该模型名称（包括被注释的行）
		if ! grep -Eq "^[[:space:]#]*${name}([[:space:]]|$)" "$CONFIG_FILE"; then
			added_models+=("$name")
			echo "$line" >>"$temp_file"
		fi
	done <<<"$models"

	mv "$temp_file" "$CONFIG_FILE"

	if [[ ${#added_models[@]} -gt 0 ]]; then
		echo "✅ 配置文件已修改，追加了以下 ${#added_models[@]} 个新模型："
		for m in "${added_models[@]}"; do
			echo "  - $m"
		done
	else
		echo "✅ 配置文件与系统模型已一致，没有发生修改（无新模型追加）。"
	fi
}

# 模式 2：根据配置文件增删模型，并自动补全信息 (Apply)
function apply_from_config() {
	# 防呆逻辑：若没有配置文件，则不能执行，避免清空系统模型
	if [[ ! -f "$CONFIG_FILE" ]]; then
		echo "❌ 错误: 未找到 $CONFIG_FILE ！已终止操作，避免误清空系统模型。"
		exit 1
	fi

	# 读取配置文件中期望的模型（过滤空行和注释行，提取第一列）
	local desired_models=$(awk '/^[[:space:]]*[^#[:space:]]/ {print $1}' "$CONFIG_FILE")
	# 读取系统目前的模型
	local current_models=$(ollama list | tail -n +2 | awk 'NF>0 {print $1}')

	declare -a to_pull=()
	declare -a to_remove=()

	# 1. 找出缺失的模型 (待 Pull)
	for d_model in $desired_models; do
		if ! echo "$current_models" | grep -Fqxw "$d_model"; then
			to_pull+=("$d_model")
		fi
	done

	# 2. 找出多余的模型 (待 Rm)
	for c_model in $current_models; do
		if ! echo "$desired_models" | grep -Fqxw "$c_model"; then
			to_remove+=("$c_model")
		fi
	done

	# 3. 打印预览并要求用户确认
	if [[ ${#to_pull[@]} -eq 0 && ${#to_remove[@]} -eq 0 ]]; then
		echo "✅ 系统模型与配置文件一致，没有需要下载或删除的模型。"
	else
		echo "=========================================="
		echo "📊 变更预览："
		if [[ ${#to_pull[@]} -gt 0 ]]; then
			echo -e "\n📥 以下模型将被 下载 (Pull):"
			for m in "${to_pull[@]}"; do echo "  + $m"; done
		fi

		if [[ ${#to_remove[@]} -gt 0 ]]; then
			echo -e "\n🗑️ 以下模型将被 删除 (Rm):"
			for m in "${to_remove[@]}"; do echo "  - $m"; done
		fi
		echo "=========================================="

		# 强制拦截用户确认
		read -p "⚠️ 确认执行以上操作吗？[y/N]: " confirm
		if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
			echo "🚫 用户取消了操作。"
			exit 0
		fi

		# 执行下载
		for m in "${to_pull[@]}"; do
			echo "📥 正在下载模型: $m ..."
			if ! ollama pull "$m"; then
				echo "❌ 错误: 下载 $m 失败！"
			fi
		done

		# 执行删除
		for m in "${to_remove[@]}"; do
			echo "🗑️ 正在删除模型: $m ..."
			ollama rm "$m"
		done
	fi

	# 4. 自动补全：更新配置文件，补全 SIZE 等信息，同时保留用户的注释和排版
	echo "🔄 正在检查并自动补全 $CONFIG_FILE 中的模型信息..."
	local temp_file=$(mktemp)
	local full_list=$(ollama list | tail -n +2)

	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
			echo "$line" >>"$temp_file"
		else
			local m_name=$(echo "$line" | awk '{print $1}')
			local full_info=$(echo "$full_list" | awk -v name="$m_name" '$1 == name {print $0}')
			if [[ -n "$full_info" ]]; then
				echo "$full_info" >>"$temp_file"
			else
				echo "$line" >>"$temp_file"
			fi
		fi
	done <"$CONFIG_FILE"

	mv "$temp_file" "$CONFIG_FILE"
	echo "✅ 模型配置同步处理完成！"
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
	echo "  save  : 将当前系统中的模型保存/更新到 $CONFIG_FILE 中，并打印修改记录。"
	echo "  apply : 根据 $CONFIG_FILE 预览增删系统模型，用户确认后执行，并自动补全信息。"
	exit 1
	;;
esac
