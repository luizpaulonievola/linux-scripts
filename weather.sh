#!/bin/bash

# --- Configuração ---
API_KEY=""  # Substitua pela sua chave de API
CITY=""                         # Sua cidade e código do país
UNITS="metric"                             # metric = Celsius, imperial = Fahrenheit
LANG="pt_br"                               # Para descrição em português (se suportado pela API)
SYMBOL_DEG="°C"                            # Símbolo de grau (mude para °F se usar imperial)

# --- Verificação ---
# Opcional: verificar se jq está instalado
# if ! command -v jq &> /dev/null; then
#     echo "Erro: jq não encontrado. Instale-o (ex: sudo apt install jq)"
#     exit 1
# fi

# --- Chamada à API e Processamento ---
WEATHER_JSON=$(curl -s "http://api.openweathermap.org/data/2.5/weather?q=${CITY}&appid=${API_KEY}&units=${UNITS}&lang=${LANG}")

# Verificar se a chamada curl foi bem-sucedida e se o JSON é válido (básico)
if [ -z "$WEATHER_JSON" ] || ! echo "$WEATHER_JSON" | jq -e . > /dev/null 2>&1; then
    echo "Erro ao buscar dados ou JSON inválido."
    # Você pode querer uma saída mais específica no Conky, como "Weather N/A"
    exit 1
fi

# Usar jq para extrair e formatar DADOS EM VÁRIAS LINHAS
echo "$WEATHER_JSON" | jq -r \
    --arg SYMBOL_DEG "$SYMBOL_DEG" '  # Passa a variável SYMBOL_DEG para dentro do jq
    "🌡️ \(.main.temp | round)\($SYMBOL_DEG) (\(.weather[0].description | ascii_upcase))", # Temperatura e Descrição
    "Min: \(.main.temp_min | round)\($SYMBOL_DEG) / Max: \(.main.temp_max | round)\($SYMBOL_DEG)", # Mínima e Máxima
    "💧 Humidade: \(.main.humidity)%",  # Humidade
    "💨 Vento: \(.wind.speed) m/s",    # Vento
    "☀️ Nascer: \(.sys.sunrise | strftime("%H:%M")) | 🌙 Pôr: \(.sys.sunset | strftime("%H:%M"))" # Nascer/Pôr do Sol formatado HH:MM
    '
# A vírgula entre as strings no jq -r faz com que cada string seja impressa em uma nova linha.