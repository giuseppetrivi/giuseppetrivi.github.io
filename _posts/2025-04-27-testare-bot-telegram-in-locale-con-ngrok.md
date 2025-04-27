---
layout: post
title: Testare bot Telegram in locale con ngrok
description:
  I bot Telegram necessitano di un webhook, ovvero di un file accessibile tramite URL, per eseguire il loro codice. Per sviluppare un bot Telegram, quindi, è necessario caricare ogni modifica sul server che ospita il codice, e questo può rallentare di molto la produzione. In questo articolo mostro come sviluppare bot Telegram in locale utilizzando ngrok con l'ausilio di un semplice script Python sviluppato da me per automatizzare diverse operazioni.
date: 2025-04-27 12:32 +0200
image:
  path: /assets/img/testare-bot-con-ngrok/ngrok-logo.png
  #alt: Logo di ngrok
categories: [Progetto, TelegramBot]
tags: [telegram, bot, testing, script]
---


## Il problema
Prima di mandare un software in produzione e renderlo accessibile al pubblico è necessario testarlo in un ambiente circoscritto (ad esempio in locale sul proprio PC) per verificarne il corretto funzionamento.

Durante [la loro configurazione](https://core.telegram.org/bots/tutorial), i bot Telegram hanno bisogno di un [webhook](https://it.wikipedia.org/wiki/Webhook), ovvero un collegamento ad uno specifico file di codice (ad esempio un file PHP) presente sul web e accessibile tramite URL. Questo file è scritto appositamente per fungere da punto di accesso per l'elaborazione delle richieste inviate dall'interfaccia del bot Telegram. Questo, però, significa anche che non è possibile sviluppare un bot Telegram in locale in quanto le richieste vengono processate sul server indicato durante la configurazione iniziale.

Per ogni modifica al codice del bot, va utilizzato un collegamento FTP per caricare i file modificati sul server e solo successivamente può essere testato il bot. Tutto ciò complica e rallenta la produzione.


## Una soluzione: **ngrok**
Una possibile soluzione a questa scomoda dinamica è offerta da [ngrok](https://ngrok.com/). Questo strumento consente ad una cartella locale (o ad un servizio locale in generale) di essere accessibile sul web in sicurezza tramite un URL appositamente generato. Quando viene eseguito questo software da linea di comando, su una determinata porta in locale viene avviato un **agente ngrok** (un software) che crea una connessione tramite **TLS** alla rete globale di server ngrok, chiamata **ngrok edge**, avendo, così, un tunnel sicuro tra le risorse locali e i server ngrok. Poi verrà fornito da ngrok l'URL pubblico dal quale sarà possibile accedere a queste risorse tramite la ngrok edge [[approfondimento qui](https://ngrok.com/docs/how-ngrok-works/)].

Utilizzando l'URL fornito da ngrok come webhook di un bot Telegram, una modifica del codice in locale sarà sufficiente per avere i cambiamenti disponibili dall'interfaccia del bot, avendo un feedback praticamente istantaneo. Per sfruttare questo servizio andrebbero seguiti dei passaggi, che io ho reso per la maggior parte automatici con uno script reperibile [su GitHub](https://github.com/giuseppetrivi/ngrok-for-testing-telegram-bot) e che spiego nel prossimo paragrafo.


## Come utilizzare ngrok con un semplice script
Come accennato sopra, la necessità di testare bot Telegram in locale semplicemente modificando e salvando il codice mi ha spinto ad usare ngrok. Questo, però, comporta che ogni volta che si vuole sviluppare e testare il proprio bot Telegram in locale bisogna eliminare il webhook "di produzione" e inserire come webhook l'URL fornito da ngrok, che rimanda al progetto locale. 

Grazie allo script Python che ho realizzato, con all'ausilio della libreria `pyngrok`, è possibile svolgere tutti questi passaggi, dal cambio dei webhook alla creazione del tunnel ngrok, in automatico.

#### Prerequisiti
I prerequisiti necessari per sfruttare questo servizio sono:
- la creazione di un bot Telegram e il token relativo ([tutorial ufficiale qui](https://core.telegram.org/bots/tutorial))
- [Python](https://www.python.org/) (per l'esecuzione degli script)
- [Registrazione su ngrok](https://dashboard.ngrok.com/signup)
- [Download di ngrok](https://ngrok.com/downloads/windows) (seguire gli step 1 e 2 [qui](https://ngrok.com/docs/getting-started/))
- [Download della libreria `pyngrok`](https://pypi.org/project/pyngrok/)
- Un tool per avviare un server locale (come [XAMPP](https://www.apachefriends.org/it/index.html))
- [Download dello script in Python (repository GitHub)](https://github.com/giuseppetrivi/ngrok-for-testing-telegram-bot)

#### File nel repository
Nel [repository](https://github.com/giuseppetrivi/ngrok-for-testing-telegram-bot) ci sono tre file.

Il file `ngrok.yml` è il file di configurazione principale utilizzato da ngrok che va modificato nel punto "*authtoken*", inserendo il token reperibile dal proprio account di ngrok dal menù laterale alla voce "Your Authtoken". Questo file va poi copiato nella cartella di configurazione di ngrok sul proprio PC. Il percorso di questa cartella dipende dal sistema operativo ([qui sono indicati i possibili path](https://ngrok.com/docs/agent/config/)).

Il file `Webhook.py` contiene una classe per la gestione dei webhook dei bot Telegram, utilizzata dallo script principale `autoNgrok.py`, che riceve due argomenti da riga di comando:
- <u>path della cartella</u> che contiene il codice (andrebbe messa in un punto accessibile dal server locale, ad esempio nel caso di XAMPP in `.../xampp/htdocs/cartella-bot/`)
- <u>token del bot Telegram</u>

Questi due parametri possono essere anche inseriti direttamente nello script, per non doverli inserire da capo ogni volta.

#### Funzionamento dello script
Dopo aver soddisfatto i prerequisiti e dopo aver avviato il server locale (ad esempio tramite XAMPP), lo script `autoNgrok.py` può essere eseguito da linea di comando e svolge i seguenti passaggi:
1. crea il tunnel ngrok e genera l'URL per accedervi
2. l'URL generato viene combinato con il percorso della cartella locale (passato come primo argomento)
3. viene eliminato il webhook impostato per il bot Telegram (se esiste) tramite il token passato come secondo argomento
4. viene settato il nuovo webhook per il bot Telegram, ovvero l'URL ngrok della cartella locale (contenente il bot da testare e il file entrypoint per il bot)
5. lo script resta in esecuzione per mantenere il tunnel attivo, fino a che non lo si chiude manualmente