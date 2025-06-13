---
layout: post
title: Testare bot Telegram in locale con ngrok
description:
  I bot Telegram necessitano di un webhook, ovvero di un file accessibile tramite URL, per eseguire il loro codice. Per sviluppare un bot Telegram, quindi, è necessario caricare ogni modifica sul server che ospita il codice, e questo può rallentare di molto il ciclo di sviluppo. In questo articolo mostro come sviluppare bot Telegram in locale utilizzando ngrok con l'ausilio di un semplice script Python sviluppato da me per automatizzare diverse operazioni.
date: 2025-04-27 12:32 +0200
image:
  path: /assets/img/ngrok-logo.webp
  # alt: Logo di ngrok
categories: [Progetto]
tags: [telegram-bot, testing, script, python]
---


## Il problema
Prima di mandare un software in produzione e renderlo accessibile al pubblico è necessario eseguirlo in un ambiente isolato (ad esempio in locale sul proprio PC) per effettuare test e debug del codice con lo scopo di verificarne il corretto funzionamento.

Durante [la loro configurazione](https://core.telegram.org/bots/tutorial), i bot Telegram hanno bisogno di un [webhook](https://it.wikipedia.org/wiki/Webhook), ovvero un collegamento ad uno specifico endpoint (ad esempio un file PHP) presente sul web e accessibile tramite URL. Questo file è scritto appositamente per fungere da punto di accesso per l'elaborazione delle richieste inviate dall'interfaccia del bot Telegram. Questo vuol dire che per sviluppare un bot Telegram, verificandone contemporaneamente il corretto funzionamento, bisogna comunque inserire tutto il progetto (file di codice) in un server accessibile dal web tramite URL. Quindi, per ogni modifica al codice del bot va utilizzato un collegamento FTP per caricare i file modificati sul server e solo successivamente può essere testato attraverso l'interfaccia di Telegram. Tutto ciò complica  notevolmente il processo di sviluppo e ne rallenta l'efficienza.

## Una soluzione: **ngrok**
Una possibile soluzione a questa scomoda dinamica è offerta da [ngrok](https://ngrok.com/), uno strumento che consente ad un servizio in esecuzione locale di essere accessibile dal web in sicurezza tramite un URL provvisorio appositamente generato. Quando viene eseguito questo software da linea di comando, su una determinata porta in locale viene avviato un **agente ngrok** che crea una connessione tramite [**TLS**](https://it.wikipedia.org/wiki/Transport_Layer_Security) alla rete globale di server ngrok, chiamata **ngrok edge**, avendo, così, un tunnel sicuro tra le risorse locali e i server ngrok. Poi ngrok fornirà l'URL pubblico dal quale sarà possibile accedere a queste risorse tramite la rete ngrok edge [[approfondimento qui](https://ngrok.com/docs/how-ngrok-works/)].

In tal modo, utilizzando l'URL fornito da ngrok come webhook di un bot Telegram, una modifica del codice in locale sarà sufficiente per ottenere i cambiamenti in maniera istantanea sull'interfaccia del bot, avendo un feedback rapido. 

Per sfruttare questo servizio andrebbero seguiti una serie di passaggi che io ho reso per la maggior parte automatici con uno script reperibile [da questo repository di GitHub](https://github.com/giuseppetrivi/ngrok-for-testing-telegram-bot) e che spiego nel prossimo paragrafo.

---
## Uno script per migliorare lo sviluppo
Come accennato sopra, la necessità di testare bot Telegram in locale semplicemente modificando e salvando il codice mi ha spinto ad usare ngrok. L'URL generato da ngrok, però, cambia ogni volta che si avvia questo servizio. Quindi ogni volta che si vuole sviluppare e testare il proprio bot Telegram in locale bisogna eliminare il webhook precedentemente settato e inserire come webhook l'URL più recente fornito da ngrok, che rimanda al progetto locale.

### Come funziona?
Il normale flusso di impostazione di un bot Telegram, spiegato più nel dettaglio [qui](https://core.telegram.org/bots/tutorial), risulta brevemente come segue:
1. dopo una serie di passaggi, viene fornito da [@BotFather](https://telegram.me/BotFather) il `<TOKEN>` del bot creato;
2. attraverso una chiamata del tipo `https://api.telegram.org/bot<TOKEN>/setWebhook?url=<ENDPOINT_URL>` viene impostato il webhook, ovvero l'endpoint che verrà interpellato all'inizio di ogni richiesta inviata dall'interfaccia del bot Telegram;

<a href="https://google.it" name="ngrok-script-flow"></a>
Se si vuole utilizzare ngrok per sviluppare il bot in locale ed, eventualmente, su un bot (token) differente adibito appositamente per il testing, allora andrebbero eseguiti i seguenti passaggi:

1. creare il tunnel ngrok e ottenere l'URL provvisorio generato da ngrok, da utilizzare come webhook
2. eliminare il precedente webhook associato al bot con una chiamata del tipo `https://api.telegram.org/bot<TOKEN>/deleteWebhook`
3. impostare il nuovo webhook, utilizzando l'URL fornito da ngrok, con una chiamata del tipo `https://api.telegram.org/bot<TOKEN>/setWebhook?url=<NGROK_URL>`

Lo script presente nel repository automatizza questo processo, evitando di dover eseguire questi passaggi manualmente e permettendo la creazione di configurazioni prestabilite per scenari di sviluppo/test ricorrenti. Nello specifico, lo script `auto_ngrok.py` accetta tre argomenti da linea di comando:
- `-f LOCAL_FOLDER_PATH`: il percorso del file che funge da endpoint del webhook. Questo file deve trovarsi nella cartella del localhost (ad esempio, in XAMPP, è `.../xampp/htdocs/`)
- `-t TELEGRAM_BOT_TOKEN`: il token del bot Telegram.
- `-c CUSTOM_CONFIG_FILE`: il nome del file di configurazione personalizzato per riutilizzare facilmente determinate impostazioni

Se viene usato l'argomento `-c`, gli altri parametri (`-f` and `-t`) saranno letti dal file di configurazione. Altrimenti, dovranno essere specificati manualmente.

Infine, si potrebbe fare in modo che lo script sia richiamabile globalmente nel terminale attraverso l'aggiunta nella variabile globale PATH (l'implementazione precisa dipende dal sistema operativo), per evitare di dover ogni volta fare riferimento al suo percorso completo di locazione nel sistema.

### Scenario di esempio
Nel seguente scenario si sta sviluppando un bot Telegram per la conversione di file da MP4 a MP3.

L'URL di produzione, dove verrà pubblicato il codice finale del bot, è `https://hosting.com/mp4mp3converter_bot/entrypoint.php`. Il token del bot di produzione finale è `123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIL`.

Il bot è in fase di sviluppo e lo si vuole testare su un altro bot creato appositamente. Inoltre, per velocizzare il ciclo di sviluppo lo si vuole sviluppare in locale.

Il server locale utilizzato è XAMPP e la cartella del localhost relativo è `C:/User/programmer01/xampp/htdocs/`. In questa cartella si inserisce la cartella `mp4mp3converter_bot`, con al suo interno il codice relativo al bot Telegram. Il token del bot per effettuare i test è `1029384756alskdjfhgzmxncbvqpwoeiruty1029384756`.

Dopo aver clonato il repository con lo script, posso creare in quella stessa cartella un file `mp4mp3_config.json` con i seguenti valori di default:
```json
{
  "ngrok_config_file_path": "C:/path/to/ngrok/config/folder/ngrok.yml",
  "local_folder_path": "/mp4mp3converter_bot/entrypoint.php",
  "telegram_bot_token": "1029384756alskdjfhgzmxncbvqpwoeiruty1029384756"
}
```

A questo punto basterà eseguire il seguente comando, per avviare il tunneling ngrok e sviluppare il bot Telegram in locale:
```bash
py auto_ngrok.py -c mp4mp3_config
```

In alternativa, ogni volta che voglio sviluppare il bot posso eseguire il seguente comando:
```bash
py auto_ngrok.py -f "/mp4mp3converter_bot/entrypoint.php" -t "1029384756alskdjfhgzmxncbvqpwoeiruty1029384756"
```


In ogni caso l'output dovrebbe essere simile a questo:
```
ngrok URL: https://<unique_id>.ngrok-free.app/mp4mp3converter_bot/entrypoint.php
## Delete webhook: info ##
{
  "ok": true,
  "result": true,
  "description": "Webhook was deleted"
}
## Set new webhook: info ##
{
  "ok": true,
  "result": true,
  "description": "Webhook was set"
}
## General webhook info ##
{
  "ok": true,
  "result": {
    "url": "https://<unique_id>.ngrok-free.app/mp4mp3converter_bot/entrypoint.php",
    "has_custom_certificate": false,
    "pending_update_count": 0,
    "max_connections": 40,
    "ip_address": "<ip_address>"
  }
}


Info about the ngrok tunnel
        Public URL: https://<unique_id>.ngrok-free.app
        Protocol: https
        Tunnel name: <tunnel_name>
        Tunnel configuration:
{
         "addr": "http://localhost:80",
         "inspect": true
}

!! Remind to activate your localhost server (XAMPP or whatelse) !!
Press CTRL+C to stop ngrok tunneling
```

L'output mostra chiaramente [il flusso descritto nel paragrafo precedente](#ngrok-script-flow). Il file `C:/User/programmer01/xampp/htdocs/mp4mp3converter_bot/endpoint.php` viene utilizzato come endpoint del bot identificato dal token `1029384756alskdjfhgzmxncbvqpwoeiruty1029384756`.

### Debug delle richieste HTTP
Durante lo sviluppo potrebbe essere utile visionare nel dettaglio i risultati delle richieste inviate dal bot al tunnel ngrok. Per fare ciò basta visitare l'interfaccia web fornita da ngrok all'indirizzo locale `http://127.0.0.1:4040/inspect/http`, in cui per ogni richiesta verrà mostrato l'header, i parametri GET/POST, il codice di risposta e altre informazioni utili per verificare il corretto funzionamento del bot.

## Conclusioni
L'uso di ngrok unito a questo script è una scelta di sviluppo che consiglio a chiunque voglia produrre un bot Telegram. Lo script può essere arricchito di funzionalità e la libreria `pyngrok` offre numerose funzionalità per la gestione di tunnel ngrok che potrebbero essere sfruttate maggiormente. 

Accolgo volentieri suggerimenti :)