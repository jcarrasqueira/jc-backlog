# **Vulnerabilidade Subtil**

De acordo com o enunciado do projeto, cada grupo deve introduzir uma vulnerabilidade subtil que possa ser explorada por outro grupo na fase _Break‑It_. No nosso caso, a vulnerabilidade introduzida está relacionada com a forma como o campo `cipher_len` é processado durante a leitura das entradas do log, na função `verify_chain`.

A vulnerabilidade surge porque o código **confia totalmente** no valor de `cipher_len` lido do ficheiro, sem aplicar qualquer validação adicional sobre o seu tamanho máximo, coerência ou plausibilidade. O código assume que o valor lido é sempre correto e que o ficheiro não foi manipulado. No entanto, um atacante que consiga modificar diretamente o ficheiro de log pode alterar o valor de `cipher_len` para um valor incorreto, exageradamente grande ou inconsistente com o restante conteúdo.

O trecho relevante é o seguinte:

python

```
cipher_len = f.read(4)
if len(cipher_len) < 4:
    print("integrity violation")
    sys.exit(111)

ciphertext = f.read(struct.unpack("!I", cipher_len)[0])
if len(ciphertext) < struct.unpack("!I", cipher_len)[0]:
    print("integrity violation")
    sys.exit(111)
```

A vulnerabilidade subtil está aqui:

- o valor de `cipher_len` é lido diretamente do ficheiro,
    
- convertido para inteiro com `struct.unpack`,
    
- e usado imediatamente para determinar quantos bytes devem ser lidos a seguir.
    

Se um atacante manipular o ficheiro e colocar um valor de `cipher_len` muito grande (por exemplo, maior do que o tamanho real restante do ficheiro), o programa tentará ler uma quantidade de bytes impossível. Embora o código acabe por detetar a incongruência e imprimir `integrity violation`, **a tentativa de leitura excessiva pode causar comportamentos inesperados**, tais como:

- leitura incompleta que força o programa a entrar em estados não previstos,
    
- consumo excessivo de memória ao tentar alocar buffers grandes,
    
- lentidão ou bloqueio temporário do processo,
    
- possibilidade de crash dependendo da implementação da biblioteca de I/O.
    

Esta vulnerabilidade é subtil porque:

1. **Não compromete diretamente a segurança criptográfica** — o atacante não consegue forjar MACs nem quebrar a confidencialidade.
    
2. **Não permite modificar o estado lógico do log** — qualquer adulteração continua a ser detetada.
    
3. **Mas pode ser explorada para causar um crash ou comportamento anómalo**, o que é suficiente para um ataque válido na fase _Break‑It_, conforme o enunciado.
    
4. **Não é imediatamente evidente** ao ler o código, pois parece apenas uma leitura normal de dados binários.
    
5. **Depende de manipulação precisa do ficheiro**, o que a torna subtil e não trivial de explorar.
    

Assim, esta vulnerabilidade cumpre os requisitos do projeto:

- é subtil,
    
- não compromete a segurança global do protocolo,
    
- mas pode ser explorada por outro grupo para provocar um crash ou comportamento inesperado,
    
- e está diretamente relacionada com a forma como o ficheiro de log é processado.