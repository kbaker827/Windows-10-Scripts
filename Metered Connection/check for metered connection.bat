@Echo off

SET /P _SSID= What is the SSID of the hotspot:

netsh wlan show profile name="%_SSID%"

PAUSE
