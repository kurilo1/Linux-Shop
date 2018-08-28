#!/bin/bash

played=false
get_total() {
	grep total "$HOME"/cart | awk '{ print $2 }'
}

get_image() {
	local image_path=$1
	local image
	local image_file
	local num
	local name
	local price
	image_file=$(basename "$image_path")
	num=$(echo "$image_file" | awk -F "_" '{ print $1 }')
	name=$(echo "$image_file" | awk -F "_" '{ print $2 }')
	price=$(echo "$image_file" | awk -F "_" '{ print $3 }' | awk -F "." '{print $1}')
	declare -A image
	image=( ["num"]="$num" ["name"]="$name" ["price"]="$price" ["image_file"]="$image_file")
	declare -p image
}

show_board() {
	local chosen_image_path

	echo -e '				Board'
	for image_path in /var/shop/images/*; do
		#shellcheck disable=SC2046
		eval $(get_image "$image_path") # create local array "image"
		echo -e "[ ${image[num]} ]	${image[name]}	\\n	Стоимость: ${image[price]}\\n"
	done

	if [[ -s $HOME/cart ]]; then
		echo -e "Для перехода в корзину введите [cart] \\nИли выберите номер картинки"
	else
		echo -e "Выберите номер картинки"
	fi
	read -r -p ": " input
	case $input in
		cart)
			command="show_cart"
			return
			;;
		*)
			chosen_image_path=$(find /var/shop/images -name "$input*" | head -n 1 )
			if [[ -n $chosen_image_path ]]; then
				command="show_item_describe \"$chosen_image_path\""
				
			else
				echo -e 'Изображение не найдено. Пожалуйста, попробуйте еще раз.'
				command="show_board"
			fi
	esac
}

show_item_describe() {
	local image_path=$1
	#shellcheck disable=SC2046
	eval $(get_image "$image_path") # create local array "image"
	echo -e "			${image["name"]}\\n\\n"
	convert "$image_path" -resize 2000x800! jpeg:- | jp2a - --width="$(tput cols)" -i 
	echo -e "\\n\\n Стоимость: ${image["price"]}"

	if grep -q "$image_path" "$HOME/cart" 2> /dev/null; then
		echo -e 'Для удаления из корзины введите [remove]'
	else
		echo -e 'Для добавления в корзину введите [add]'
	fi
	echo -e 'Для перехода на главную введите [board]'

	read -r -p ": " input
	case $input in
		remove)
			sed -i "/${image["name"]}/d" "$HOME/cart"
			command="show_item_describe $image_path"
			return
			;;
		add)
			echo "$image_path" >> "$HOME/cart"
			command="show_cart"
			return
			;;
		board)
			command="show_board"
			return
			;;
		*)
			echo -e 'Неправильный ввод. Пожалуйста, попробуйте еще раз.'
			command="show_item_describe $image_path"
	esac
}

show_cart() {
	local total
	local chosen_image_path
	sed -i "/^total/d" "$HOME/cart"
	echo -e '				Cart'

	while IFS= read -r image_path
	do
		#shellcheck disable=SC2046
		eval $(get_image "$image_path") # create local array "image"
		echo -e "[ ${image[num]} ]	${image[name]}	\\n	Стоимость: ${image[price]}\\n"
		((total+=image[price]))
	done < <(grep -v '^ *#' < "$HOME"/cart )

	echo total "$total" >> "$HOME"/cart
	echo -e "\\nОбщая сумма заказа: $total"
	if [[ -f "$HOME"/balance ]]; then
		echo -e "У вас есть: $(cat "$HOME"/balance)"
	fi
	echo -e "\\n\\nЕсли хотите убрать товар из заказа, введите его номер"
	echo -e "Для перехода на главную введите [board]"
	echo -e "Чтобы подтвердить заказ нажимите [Enter]"

	read -r -p ": " input
	case $input in
		"")
			command="show_confirm_order"
			return
			;;
		board)
			command="show_board"
			return
			;;
		*)
			chosen_image_path=$(grep /"$input" "$HOME"/cart )
			if [[ -n $chosen_image_path ]]; then
				sed -i "/\\/$input/d" "$HOME/cart" 
			else
				echo -e 'Изображение не найдено. Пожалуйста, попробуйте еще раз.'
				command="show_cart"
			fi

	esac
}

check_balance() {
	local balance
	local total

	if [[ ! -f $HOME/balance ]]; then
		echo 0 > "$HOME"/balance
		balance=0
	else 
		balance=$(cat "$HOME"/balance)
	fi

	total=$(get_total)

	if [[ $balance -ge $total ]]; then
		#хватает денег
		sed -i "/^total/d" "$HOME/cart"
		echo total $(( balance-total )) >> "$HOME"/cart
		command=make_delivery
		return
	else
		if $played ; then
			#если клиент играл в эту сессию
			command=show_change_cart
			return
		else
			command=show_game
		fi
	fi
}

show_confirm_order() {
	echo -e "\\nОбщая сумма заказа: $(get_total)\\n"
	if [[ -f "$HOME"/balance ]]; then
		echo -e "У вас есть: $(cat "$HOME"/balance)\\n\\n"
	fi
	while [[ ! -s "$HOME"/mail ]]; do
		read -r -p "Введите ваш email: " input
		if [[ -n $input ]]; then
			echo "$input" > "$HOME"/mail
		else
			echo "Пустая строка."
		fi
	done
		echo "Ваш email \"$(cat "$HOME"/mail)\"?	[Yes/No]"
		read -r -p ": " input
		if echo "$input" | grep -iq "^y" ;then
		    command=check_balance
		    return
		else
		    rm -r "$HOME"/mail
		    while [[ ! -s "$HOME"/mail ]]; do
				read -r -p "Введите ваш email: " input
				if [[ -n $input ]]; then
					echo "$input" > "$HOME"/mail
				else
					echo "Пустая строка."
				fi
			done
		fi

}

show_change_cart() {
	echo -e "Вы набрали $(cat "$HOME"/balance)\\n
	Чтобы вернуться в корзину и изменить заказ введите [cart]\\n
	Чтобы начать играть нажимите [Enter]"
	read -r -p ": " input
	case $input in
		cart )
			command=show_cart
			return
			;;
		*)
			command=show_game
	esac
}

show_game() {
	local score
	local balance
	local total
	local wanted_score
	local game_retry=$1
	played=true

	balance=$(cat "$HOME"/balance)
	total=$(get_total)
	wanted_score=$((total-balance))
	echo "Вам нужно набрать $wanted_score баллов для того чтобы совершить покупку."

	if [[ $game_retry ]]; then
		echo -e "У вас есть одна жизнь.\\n
		После того как наберете нужное колличество, выходите из игры.\\n
		Баллы за игры суммируются и после оплаты остаются на вашем балансе."
	fi

	read -r -p "Вы готовы?"
	myman -N -o -l 1 -e -a 2>"$HOME"/.score_tmp

	score=$(grep scored "$HOME"/.score_tmp | awk '{ print $3 }')
	rm -f "$HOME"/.score_tmp
	echo "You scored $score"

	echo $((score+balance)) > "$HOME"/balance

	command=check_balance
}

make_delivery() {
	local email
	local attachment

	balance=$(cat "$HOME"/balance)
	total=$(get_total)
	#echo "___total $total"
	#echo "___balance $balance"
	echo $(( balance-total )) > "$HOME"/balance

	sed -i "/^total/d" "$HOME/cart"

	while IFS= read -r image_path
	do
		attachment+=" $image_path"
	done < <(grep -v '^ *#' < "$HOME"/cart )


	email=$(cat "$HOME"/mail)
	rm -f "$HOME"/cart


	#echo "$attachment"
	bash /var/shop/mutt-smtp.sh "$email" "Delivery from Images Shop" "" "$attachment"

	read -r -p "Письмо отправлено. Можете проверить вашу почту :)"

	command=show_board
}

main() {
	#touch "$HOME"/cart
	#touch "$HOME"/balance
	#realization goto
	while true; do
	#	echo $command
		eval "$command"
	done
}

#first command
command=show_board

#run
main