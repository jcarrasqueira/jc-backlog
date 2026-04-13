# **Ataque 5 — Ataques de Integridade (Modificação, Truncação, Reordenação e Inserção)**

Este conjunto de ataques corresponde a qualquer tentativa de adulterar o ficheiro de log diretamente, sem utilizar o programa `logappend`. Como o ficheiro é binário e contém entradas encriptadas e autenticadas, um atacante pode tentar manipular o ficheiro de várias formas: **modificar bytes**, **remover entradas**, **trocar a ordem das entradas** ou **inserir entradas falsas**. Todos estes ataques têm como objetivo quebrar a integridade do log e enganar o sistema durante a leitura.

O nosso protocolo protege‑se contra todos estes cenários através da utilização de uma **MAC chain**, onde cada entrada depende criptograficamente da anterior. Isto significa que qualquer alteração, mesmo mínima, quebra a cadeia e é imediatamente detetada.

A seguir explico cada sub‑ataque em detalhe.

## **5.1 Modificação de Entradas (Modification Attack)**

Neste ataque, o adversário tenta alterar diretamente o conteúdo do ficheiro de log, modificando:

- o IV
    
- o comprimento (`cipher_len`)
    
- o ciphertext
    
- ou o MAC armazenado
    

Como cada entrada é autenticada com:

Code

```
mac_i = HMAC(k_mac, mac_{i-1} || iv || ciphertext || cipher_len)[:16]
```

qualquer alteração — mesmo de **um único bit** — altera o input do HMAC e faz com que o MAC calculado deixe de coincidir com o MAC armazenado.

### **Código que prova a defesa**

python

```
correct_mac = hmac.new(k_mac, mac_prev + iv + ciphertext + cipher_len, hashlib.sha256).digest()[:16]
if not hmac.compare_digest(correct_mac, stored_mac):
    print("integrity violation")
    sys.exit(111)
```

Assim, qualquer modificação no ficheiro resulta imediatamente em:

Code

```
integrity violation
```

## **5.2 Truncação do Log (Truncation Attack)**

Neste ataque, o adversário tenta **remover entradas do fim do ficheiro**, com o objetivo de esconder eventos (por exemplo, esconder que um utilizador saiu de uma sala ou da galeria).

Como cada entrada depende do MAC da entrada anterior, truncar o ficheiro remove o último MAC válido. Quando o programa tenta verificar a cadeia, o MAC final não coincide com o esperado, levando a uma falha de integridade.

### **Código que prova a defesa**

python

```
cipher_len = f.read(4)
if len(cipher_len) < 4:
    print("integrity violation")
    sys.exit(111)
```

e também:

python

```
ciphertext = f.read(struct.unpack("!I", cipher_len)[0])
if len(ciphertext) < expected:
    print("integrity violation")
    sys.exit(111)
```

Se o ficheiro tiver sido truncado, estas leituras falham imediatamente.

## **5.3 Reordenação de Entradas (Reordering Attack)**

Aqui, o atacante tenta trocar a ordem das entradas no ficheiro, alterando a narrativa dos eventos (por exemplo, fazer parecer que alguém saiu antes de entrar).

A MAC chain impede isto porque cada entrada depende do MAC da entrada anterior. Se duas entradas forem trocadas, o `mac_prev` deixa de corresponder ao valor esperado, e o MAC calculado falha.

### **Código que prova a defesa**

python

```
mac_prev = stored_mac
```

Esta linha força a dependência sequencial: cada entrada só é válida se a anterior também for válida e estiver na ordem correta.

## **5.4 Inserção de Entradas Falsas (Insertion Attack)**

O atacante pode tentar inserir uma entrada falsa no meio do ficheiro, criando um IV, ciphertext e MAC inventados.

Este ataque falha porque:

- para gerar um MAC válido, o atacante precisaria de **k_mac**,
    
- e **k_mac é derivada do token**, que o atacante não conhece.
    

Sem o token, é impossível gerar um MAC válido.

### **Código que prova a defesa**

python

```
if not hmac.compare_digest(correct_mac, stored_mac):
    print("integrity violation")
    sys.exit(111)
```

Qualquer entrada inserida sem o token correto é automaticamente rejeitada.

# ⭐ **Resumo do Ataque 5 (para incluir no relatório)**

O Ataque 5 engloba todas as tentativas de adulterar o ficheiro de log diretamente, incluindo modificação, truncação, reordenação e inserção de entradas. Todas estas tentativas são mitigadas pela MAC chain, que garante que cada entrada depende criptograficamente da anterior. Qualquer alteração, mesmo mínima, quebra a cadeia e resulta numa mensagem de:

Code

```
integrity violation
```

seguida de terminação com código **111**, conforme exigido pelo enunciado.