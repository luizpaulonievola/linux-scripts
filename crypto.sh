#!/bin/bash

# Função para formatar o desvio padrão
format_std() {
    printf "%.4f" "$1"
}

# Função para obter e exibir os preços de várias criptomoedas
get_crypto_data() {
    local symbols=("$@")  # Recebe todos os símbolos como argumentos
    # Itera sobre cada símbolo fornecido
    for symbol in "${symbols[@]}"; do
        # Obter os dados de 24 horas da criptomoeda
        data=$(curl -s "https://api.binance.com/api/v3/ticker/24hr?symbol=${symbol}")

        # Verifica se a resposta está vazia ou se houve erro
        if [[ -z "$data" || "$(echo "$data" | jq -r '.code')" != "null" ]]; then
            printf "%-6s | %s | %s | %s | %s | %s\n" "$symbol" "N/A" "N/A" "N/A" "N/A" "N/A"
            continue
        fi

        # Extrair os dados relevantes
        open_price=$(echo "$data" | jq -r '.openPrice')
        high_price=$(echo "$data" | jq -r '.highPrice')
        low_price=$(echo "$data" | jq -r '.lowPrice')
        last_price=$(echo "$data" | jq -r '.lastPrice')

        # Calcular o desvio padrão (considerando os preços de abertura, fechamento, máximo e mínimo)
        prices=($open_price $last_price $high_price $low_price)
        sum=0
        sum_sq=0
        n=${#prices[@]}

        for price in "${prices[@]}"; do
            sum=$(echo "$sum + $price" | bc -l)
            sum_sq=$(echo "$sum_sq + ($price^2)" | bc -l)
        done

        mean=$(echo "$sum / $n" | bc -l)
        variance=$(echo "($sum_sq / $n) - ($mean^2)" | bc -l)
        std=$(echo "sqrt($variance)" | bc -l)

        # Formatar os preços
        format_price() {
            printf "%.4f" "$1" | awk '{sub(/\.?0+$/, ""); print}'
        }

        formatted_open=$(format_price "$open_price")
        formatted_high=$(format_price "$high_price")
        formatted_low=$(format_price "$low_price")
        formatted_last=$(format_price "$last_price")
        formatted_std=$(format_std "$std")  # Formatando o desvio padrão

        # Exibir os dados formatados com 'last' primeiro
        printf "%-6s | %-10s | %-10s | %-10s | %-10s | %-10s\n" "$symbol" "$formatted_last" "$formatted_open" "$formatted_high" "$formatted_low" "$formatted_std"
    done
}

# Obtendo os preços das criptomoedas
get_crypto_data "BTCUSDT" "ETHUSDT" "SFPUSDT" "CKBUSDT" "USDTBRL"
