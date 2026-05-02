## 1. Ataques de Crash (Disponibilidade)

Estes ataques exploram falhas na gestão de recursos ou na validação de entradas para forçar a terminação do programa.

- Null Pointer Exception no `readIntersection`:
    
    - **Ataque:** Invocar o `logread -I` passando um nome que não existe no log.
        
    - **Explicação:** O método `readIntersection` chama `buildQueryIndex`. Se um dos nomes fornecidos não for encontrado no log, o `history` pode não ser preenchido corretamente. Embora o código tenha algumas verificações, a lógica de `pickSeedSubject` ou `historyFor` pode retornar `null` se não houver entradas para um dos sujeitos, levando a um crash quando o programa tenta aceder a métodos nesse objeto.
        
- Ataque de Recursividade/Batch Infinito (Batch Loop):
    
    - **Ataque:** Criar um ficheiro de batch que aponta para si mesmo (se o sistema de ficheiros permitir links) ou um batch extremamente longo que causa estouro de pilha.
        
    - **Explicação:** Embora o `LogAppend` proíba o comando `-B` dentro de um ficheiro de batch, um atacante pode tentar explorar a forma como o `BufferedReader` lida com ficheiros especiais ou pipes nomeados para bloquear a execução indefinidamente ou causar um crash por exaustão de descritores de ficheiro.
        

---

## 2. Ataques de Integridade

Estes ataques visam enganar o `logread` para aceitar dados falsos como válidos sem possuir o token.

- Ataque de Replay de Registos Individuais:
    
    - **Ataque:** Copiar uma linha cifrada legítima de um log e colá-la novamente no final do mesmo log (ou num log diferente com o mesmo token inicial).
        
    - **Explicação:** O sistema utiliza `lastEntryHash` para validar a cadeia. No entanto, se o atacante capturar uma linha que foi gerada exatamente após o estado atual do log, ele pode reinseri-la.
        
    - **Falha Específica:** Como o IV é derivado de um `Random` com semente previsível (tempo), se o atacante conseguir prever o momento em que o hash anterior coincide, ele pode reinjetar comandos antigos (ex: fazer um funcionário "entrar" novamente).
        
- Injeção de Linhas em Branco/Comentários:
    
    - **Ataque:** Inserir linhas com espaços ou caracteres invisíveis entre as entradas legítimas.
        
    - **Explicação:** No `FileManager.java`, o método `readRecords` lança uma `IntegrityViolationException` se encontrar uma linha em branco (`line.isBlank()`). Um atacante pode usar isto para causar uma negação de serviço de integridade, impedindo que o administrador consiga ler o log legítimo, apenas inserindo um único espaço numa linha nova.
        

---

## 3. Ataques de Confidencialidade

Estes ataques visam inferir dados sensíveis (nomes, tempos, salas) sem o token `-K`.

- Vazamento de Timestamp via Metadados do Ficheiro:
    
    - **Ataque:** Observar as propriedades de modificação do ficheiro (`mtime`) no sistema operativo após cada execução do `logappend`.
        
    - **Explicação:** O comando `-T timestamp` é cifrado dentro do registo. No entanto, o `logappend` atualiza o ficheiro no disco imediatamente após a invocação. Um atacante que monitorize o sistema de ficheiros pode correlacionar a hora real da escrita com os eventos, quebrando o anonimato temporal pretendido pela cifragem do timestamp.
        
- Ataque de Dicionário de Nomes (Brute Force de Texto Cifrado):
    
    - **Ataque:** Comparar o tamanho do `cipherText` Base64 com tamanhos conhecidos de nomes comuns.
        
    - **Explicação:** O `Record` é serializado de forma determinística antes de ser cifrado. O campo nome tem um tamanho fixo de prefixo (2 bytes para o comprimento) seguido dos bytes do nome.
        
    - **Inferência:** Se o atacante souber que o log contém apenas os nomes "Eva" ou "Bernardino", ele pode distinguir instantaneamente quem é quem pelo tamanho da entrada no ficheiro Base64, pois a cifragem AES-GCM não esconde o comprimento do texto limpo (apenas adiciona o overhead fixo da tag e IV).
        
- Quebra da Chave por Reutilização de Salt:
    
    - **Ataque:** Tentar quebrar o token `-K` usando Rainbow Tables.
        
    - **Explicação:** A classe `KeyDerivation` utiliza um `BASE_SALT` fixo ("Salt") para todos os logs.
        
    - **Vulnerabilidade:** Um atacante pode pré-computar chaves para tokens comuns (ex: "12345", "password", "admin") uma única vez e testá-las em qualquer log de qualquer grupo que use esta implementação, uma vez que o salt não é único por ficheiro ou por utilizador.
      
## 1. Ataques de Crash (Disponibilidade)

### Vetor: Esgotamento de Memória (Heap Exhaustion)

Este ataque foca-se no comando `-I` (interseção), que tenta carregar todos os intervalos de tempo de múltiplos utilizadores na memória RAM.

**Comandos:**

Bash

```
# 1. Primeiro, assumindo que já existe um log muito grande (ex: log_gigante.db)
# 2. Executar o logread pedindo a interseção de vários utilizadores que tenham muitos movimentos
./logread -K token_valido -I -E FuncionarioA -E FuncionarioB -G VisitanteC log_gigante.db
```

- **O que acontece:** O programa tenta construir um `QueryIndex`. Se o ficheiro tiver milhares de entradas, a JVM lançará um `OutOfMemoryError` e o programa terminará abruptamente (crash).
    

### Vetor: Manipulação de Formato (Base64 Inválido)

Explora a falta de tratamento de exceções robusto na leitura do ficheiro.

**Comandos:**

Bash

```
# 1. Criar um log legítimo
./logappend -T 1 -K segredo -A -E Alice log_teste.db

# 2. Corromper manualmente o ficheiro (ex: adicionar caracteres não-base64 como "#$!")
echo "!!!ESTE_CONTEUDO_INVALIDO!!!" >> log_teste.db

# 3. Tentar ler o log
./logread -K segredo -S log_teste.db
```

- **O que acontece:** O método `Base64.getDecoder().decode()` lançará uma `IllegalArgumentException`. Como o `FileManager` não captura especificamente este erro de formato, o programa crasha com um "stack trace" em vez de uma mensagem de erro controlada.
    

---

## 2. Ataques de Integridade

### Vetor: Truncagem de Log (Sufixo)

Demonstra que é possível apagar os eventos mais recentes sem que o sistema detete a violação de integridade.

**Comandos:**

Bash

```
# 1. Gerar três eventos
./logappend -T 1 -K segredo -A -E Bob log_corrompido.db
./logappend -T 2 -K segredo -A -E Bob -R 1 log_corrompido.db
./logappend -T 3 -K segredo -L -E Bob -R 1 log_corrompido.db

# 2. Remover a última linha do ficheiro (o evento T=3 onde o Bob sai da sala)
# No Linux/macOS pode usar 'sed' para remover a última linha:
sed -i '$d' log_corrompido.db

# 3. Verificar o estado
./logread -K segredo -S log_corrompido.db
```

- **Resultado esperado:** O programa retorna `0` (sucesso) e diz que o Bob ainda está na sala `1`, provando que o atacante conseguiu apagar o registo de saída sem disparar o erro "integrity violation".
    

---

## 3. Ataques de Confidencialidade

### Vetor: Inferência por Tamanho de Mensagem

Mesmo cifrado, o tamanho do ficheiro revela o comprimento do nome da pessoa.

**Comandos:**

Bash

```
# 1. Criar duas entradas com nomes de tamanhos diferentes
./logappend -T 1 -K segredo -A -E Ana log_confidencial.db
./logappend -T 2 -K segredo -A -E Bernardino log_confidencial.db

# 2. Listar o ficheiro e contar os bytes de cada linha
ls -l log_confidencial.db
# Ou ver as linhas em Base64
cat log_confidencial.db
```

- **Análise:** A linha de "Bernardino" será significativamente maior que a de "Ana" devido à serialização em `Encryption.java`. O atacante sabe quem entrou apenas pelo tamanho da string Base64, violando a confidencialidade do nome.
    

### Vetor: Previsibilidade de IV (Nonce Reuse)

A semente do gerador de números aleatórios é baseada no tempo atual.

**Procedimento:**

1. O atacante executa um script que tenta adivinhar o `System.currentTimeMillis() / 10` do momento em que o log foi criado.
    
2. Como o `Random` de Java é determinístico, se a semente for igual, todos os IVs gerados serão iguais.
    
3. **Ataque:** Ao prever o IV e o hash anterior (que é guardado em texto limpo no ficheiro), o atacante pode usar técnicas de criptoanálise para recuperar o conteúdo original ou a chave GHASH do AES-GCM.      
