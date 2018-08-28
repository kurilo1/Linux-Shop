#!/bin/bash 

read -r -p 'Enter your name: ' name 
if [[ -n $name ]]; then
 	if sudo adduser --home "/home/$name" --gecos "" --quiet "$name" --shell /var/shop/shop.sh; then
		read -r -p 'Enter your email: ' email
		if [[ -n $email ]]; then
			sudo touch "/home/$name/mail"
			echo "$email" | sudo tee "/home/$name/mail" > /dev/null
		fi
		echo 'Ok, now you can login with your login and password'
	fi
fi
