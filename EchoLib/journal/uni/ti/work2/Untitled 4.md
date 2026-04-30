rooÓtimo, o recurso Ingress foi criado com sucesso. No entanto, como podes ver na coluna **ADDRESS**, ele ainda está vazio.

Isto acontece porque o Google Cloud está a comunicar com o Ingress Controller para reservar um IP público e configurar o Load Balancer. Este processo demora normalmente entre **2 a 5 minutos**.

Aqui estão os próximos passos:

### 1. Aguardar pelo IP

Continua a verificar o estado até que um IP apareça na coluna `ADDRESS`:

Bash

```
kubectl get ingress group8-ingress --watch
```

_(Podes usar `--watch` para não teres de repetir o comando; ele avisar-te-á assim que o IP mudar)._

### 2. Confirmar o Ingress Controller

Se o IP demorar mais de 5-10 minutos a aparecer, é muito provável que ainda não tenhas instalado o **NGINX Ingress Controller** no teu cluster GKE. O Ingress sozinho é apenas uma "regra", ele precisa de um "servidor" (o Controller) para funcionar.

Se ainda não o instalaste, corre este comando:

Bash

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

### 3. Onde encontrar o IP "Real"

O IP que vai aparecer no comando `get ingress` é o mesmo IP do serviço do Controller. Podes também vê-lo aqui:

Bash

```
kubectl get svc -n ingress-nginx
```

Procura pelo `EXTERNAL-IP` do serviço chamado `ingress-nginx-controller`.

### 4. Testar a rota (Exemplo)

Assim que tiveres o IP (vamos supor que é `34.120.10.20`), o teu teste será:

- **Review Service:** `http://34.120.10.20/reviews-service`
    
- **Recommendations:** `http://34.120.10.20/recommendations-service`
    

**Dica importante:** Reparei que no teu ficheiro `11-ingress.yaml` original, os caminhos eram `/reviews-service` e `/recommendations-service`. Se usares a configuração que o Tiago enviou depois, os caminhos mudam para `/reviews` e `/recommendations`. Confirma qual deles aplicaste para não teres erros 404!

#### Opção A: Usar "Rewrite Target" (Recomendado para manter o código limpo)

Podes dizer ao Ingress para "remover" o prefixo `/reviews` antes de enviar o pedido para o microserviço. Para isso, precisas de adicionar uma anotação no teu `11-ingress.yaml`:

YAML

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: group8-ingress
  annotations:
    # Esta linha limpa o prefixo /reviews para que o FastAPI receba apenas /health
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /reviews(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: review-service
                port:
                  number: 8003
```

_Com isto, um pedido para `/reviews/health` chega ao FastAPI como `/health`._

---

#### Opção B: Ajustar o FastAPI (O que o Tiago sugeriu)

Podes mudar a "base" da tua API no código Python. O FastAPI permite definir um `root_path`. Na criação da app, farias:

Python

```
app = FastAPI(
    title="Review System API",
    root_path="/reviews", # Adiciona isto
    version="1.0.0",
    # ... resto das configs
)
```

Se fizeres isto, todas as rotas no código permanecem `@app.get("/health")`, mas a aplicação "sabe" que está atrás de um proxy com o prefixo `/reviews`.

---

### Checklist Final para Deploy:

1. **Instalar o Controller:** Se ainda não o fizeste, corre o comando do `ingress-nginx` (vê a minha resposta anterior).
    
2. **Verificar nomes dos Serviços:** No teu Ingress, o backend chama-se `review-service`. Confirma se no teu ficheiro `09-reviews-service.yaml` o `metadata: name:` do Service é exatamente esse.
    
3. **Base de Dados:** Garante que o Job `03-populate-db-phase5.yaml` terminou com sucesso antes de testares as rotas de `/ratings`, senão a API vai dar erro 500 ao tentar ler tabelas vazias.
    

**Como testar agora:** Depois de obteres o IP, tenta: `curl http://<EXTERNAL-IP>/reviews/health`

Se responder `{"status": "ok"}`, o teu Ingress está perfeito!