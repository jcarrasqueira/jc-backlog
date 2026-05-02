Com base no código fornecido e nos requisitos da **Fase 2 (Break It)**, aqui está uma análise de possíveis vetores de ataque divididos pelas três categorias solicitadas.

---

## 1. Ataques de Crash (Disponibilidade)

Estes ataques visam interromper o funcionamento das ferramentas `logappend` ou `logread` através de exceções não tratadas ou consumo excessivo de memória.

### Vetor: Esgotamento de Memória via `Intersection`

- **Descrição:** O método `readIntersection` no `LogRead` constrói um índice em memória (`QueryIndex`) de todos os registros para os nomes fornecidos.
    
- **Ataque:** Um atacante pode criar um ficheiro de log legítimo extremamente grande (gigantesco) com milhares de entradas de movimentos para vários usuários. Ao executar `logread -I` com múltiplos nomes, o programa tentará carregar e indexar todas essas movimentações em estruturas `HashMap` e `ArrayList`.
    
- **Justificação:** Se o tamanho do log exceder a memória heap disponível da JVM, o programa lançará um `OutOfMemoryError`, resultando num crash. Isto é uma vulnerabilidade de segurança pois permite a negação de serviço (DoS) da ferramenta de auditoria.
    

### Vetor: Malformed Base64 ou Delimitadores

- **Descrição:** O método `Entry.fromLine` utiliza `split(",", -1)` e depois descodifica partes via `Base64.getDecoder().decode()`.
    
- **Ataque:** Modificar manualmente o ficheiro de log para incluir caracteres não-Base64 ou remover vírgulas.
    
- **Justificação:** Embora o código capture algumas exceções, uma string de Base64 malformada ou truncada pode causar um `IllegalArgumentException` que, se não for capturado corretamente no ciclo principal de leitura, interrompe a execução abruptamente.
    

---

## 2. Ataques de Integridade

O objetivo é modificar o log sem o token de autenticação de forma que o `logread` ainda o considere válido.

### Vetor: Truncagem de Log (Sufixo)

- **Descrição:** O sistema utiliza um encadeamento de hashes (`hashOfLastEntry`) para garantir a integridade da sequência. Cada entrada guarda o hash da entrada anterior.
    
- **Ataque:** Um atacante pode remover as últimas $N$ linhas do ficheiro de log.
    
- **Explicação:** Como cada linha valida apenas o que veio _antes_ dela, se o atacante remover as últimas linhas, a cadeia de hashes das linhas restantes permanece perfeitamente válida. O `logread` lerá o log "encurtado", acreditará que é o estado atual da galeria e não detectará que eventos recentes foram apagados (ex: apagar o registo de saída de um ladrão).
    
- **Consequência:** Violação de integridade por omissão de dados históricos sem disparar o `integrity violation`.
    

---

## 3. Ataques de Confidencialidade

O objetivo é extrair informações do log (nomes, salas, tempos) sem possuir o token `-K`.

### Vetor: Oráculo de Reutilização de IV (Nonce)

- **Descrição:** A classe `Encryption` utiliza um `java.util.Random` (não-criptográfico) inicializado com `System.currentTimeMillis() / 10` como semente para gerar os IVs (Nonces) do AES-GCM.
    
- **Ataque:** Prever os IVs gerados.
    
- **Explicação:** Como a semente depende do tempo do sistema (com precisão de centésimos de segundo), um atacante que saiba aproximadamente quando o log foi escrito pode prever a semente e, consequentemente, a sequência de IVs gerada pelo `Random`. Se dois logs forem criados no mesmo milissegundo ou se o atacante conseguir forçar colisões de IV, o modo GCM torna-se vulnerável.
    
- **Extração de Dados:** A reutilização de IV em AES-GCM é catastrófica; permite recuperar o segredo de autenticação (GHASH key) e, em muitos casos, o conteúdo em texto limpo através de operações de XOR entre as cifras.
    

### Vetor: Vazamento por Metadados (Tamanho das Mensagens)

- **Descrição:** O código cifra os registos, mas o tamanho do `cipherText` é proporcional ao tamanho do nome do utilizador.
    
- **Ataque:** Análise de tráfego/tamanho.
    
- **Explicação:** Como os nomes têm comprimentos variáveis, um atacante pode olhar para o ficheiro Base64 e, pelo tamanho da string, inferir qual pessoa entrou. Por exemplo, se "Bob" (3 letras) e "Maximilian" (10 letras) são visitantes frequentes, as entradas de Maximilian serão visivelmente maiores no ficheiro de log, mesmo estando cifradas.
    
- **Consequência:** Permite inferir quem está na galeria e as suas rotinas apenas observando o crescimento do ficheiro.
  
  Para concretizar a **Parte 2: Break It** com base no código fornecido e nos requisitos do `SRSD_project.pdf`, aqui estão os comandos e procedimentos para demonstrar as vulnerabilidades identificadas.

---

## 1. Ataque de Crash (Disponibilidade)

O objetivo é forçar um erro de memória ou uma exceção não tratada que interrompa o programa.

### Comando de Exploração (Esgotamento de Memória)

Se o log for suficientemente grande, o processamento de interseção no `LogRead.java` falhará ao tentar manter todos os intervalos de tempo em memória.

Bash

```
# 1. Gerar um log com milhares de entradas de movimento para dois usuários (ex: Alice e Bob)
# 2. Executar a ferramenta logread com o comando de interseção
./logread -K secret -I -E Alice -E Bob huge_log.db
```

**Justificação Técnica:** O método `buildQueryIndex` no `LogRead.java` cria objetos `SubjectHistory` e `int[]` para cada entrada de sala no log. Em sistemas com memória limitada (heap da JVM), uma sequência massiva de entradas `-A -R` e `-L -R` causará um `java.lang.OutOfMemoryError`, derrubando a ferramenta de auditoria.

---

## 2. Ataque de Integridade (Modificação sem Token)

Este ataque demonstra que é possível alterar o estado da galeria sem disparar a mensagem "integrity violation".

### Vetor: Truncagem de Sufixo (Apagar o Passado Recente)

O sistema usa um encadeamento onde cada entrada contém o hash da anterior (`hashOfLastEntry`). No entanto, não há um "MAC de ficheiro completo" ou marcador de fim de ficheiro assinado.

**Passos para o Ataque:**

1. **Criar um log legítimo:**
    
    Bash
    
    ```
    ./logappend -T 1 -K secret -A -E Alice gallery.db
    ./logappend -T 2 -K secret -A -E Alice -R 1 gallery.db
    ./logappend -T 3 -K secret -L -E Alice -R 1 gallery.db  # Alice sai da sala
    ```
    
2. **Modificar o ficheiro manualmente (Ataque):**
    
    Abra o ficheiro `gallery.db` e **remova a última linha** (o evento T=3).
    
3. **Verificar com logread:**
    
    Bash
    
    ```
    ./logread -K secret -S gallery.db
    ```
    

**Resultado:** O `logread` processará as duas primeiras linhas normalmente. Como a linha T=2 contém o hash da linha T=1, a cadeia está íntegra até ali. O programa imprimirá que Alice ainda está na sala 1, ignorando que ela já saiu, sem detetar que o ficheiro foi truncado.

---

## 3. Ataque de Confidencialidade (Extração de Dados)

O objetivo é inferir informações sem saber o valor de `-K <token>`.

### Vetor: Análise de Metadados (Tamanho das Mensagens)

O código em `Encryption.java` cifra o registo, mas o tamanho do texto cifrado resultante depende diretamente do tamanho do nome do utilizador no `Record`.

**Passos para o Ataque:**

1. **Observar o ficheiro de log:**
    
    Bash
    
    ```
    cat gallery.db
    ```
    
2. **Análise visual (Exemplo de linhas Base64):**
    
    - `Linha 1 (Alice):` Conteúdo Base64 de tamanho $X$
        
    - `Linha 2 (Maximilian):` Conteúdo Base64 de tamanho $X + 12$ bytes
        

**Explicação:** Mesmo sem o token, o atacante consegue distinguir entre utilizadores com nomes curtos e nomes longos. Se o atacante souber que apenas "Alice" e "Maximilian" trabalham na galeria, ele saberá exatamente quem entrou apenas contando os caracteres da string Base64 no ficheiro.

### Vetor: Previsibilidade do IV (Nonce Reuse)

O IV é gerado usando `java.util.Random` com uma semente baseada no tempo do sistema dividido por 10.

Java

```
// Em Encryption.java:
this.r = new Random(System.currentTimeMillis()/10); 
```

**Comando de Ataque:** Se o atacante conseguir executar o `logappend` ou observar o momento exato da criação do log, ele pode instanciar um `java.util.Random` com a mesma semente temporal e prever todos os IVs que serão usados nas próximas entradas. Em AES-GCM, a previsibilidade do IV (especialmente a sua repetição) permite que um atacante recupere a chave de autenticação e decifre o conteúdo.

---

### Resumo dos Códigos de Retorno

- **Sucesso do Ataque de Integridade:** O programa corre e mostra dados falsos (retorno `0`).
    
- **Falha (Defesa a funcionar):** O programa imprime `integrity violation` e retorna `111`.
    
- **Argumentos Inválidos:** O programa imprime `invalid` e retorna `111`.
  
  
  
  ___
  
  