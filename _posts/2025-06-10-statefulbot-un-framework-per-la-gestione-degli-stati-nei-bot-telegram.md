---
layout: post
title: "StatefulBot: un framework per la gestione degli stati nei bot Telegram"
description:
  Ogni messaggio inviato dall'interfaccia di un bot Telegram viene processato dallo stesso webhook associato ad esso. Se si volessero gestire dei comandi validi solo in determinati contesti oppure intere procedure e flussi precisi di comandi sequenziali, allora per ogni richiesta andrebbe identificato il contesto nel quale ci si trova e andrebbero smistati gli input verso i "pezzi di codice" realizzati appositamente per gestirlo. La progettazione di un'architettura del genere può risultare complessa. In questo articolo presento il mio framework, StatefulBot, e i motivi che mi hanno portato al suo utilizzo nei miei progetti.
date: 2025-06-10 15:22 +0200
image:
  path: /assets/img/telegram-states-3.webp
  # alt: Immagine generata da AI
categories: [Progetti]
tags: [telegram-bot, framework, architettura, php]
---

## Il problema della gestione degli stati 
Le API per gestire le richieste di un bot Telegram sono *stateless*, quindi ogni richiesta è nuova per il webhook del bot. Se si desidera creare una procedura complessa suddivisa in più parti sequenziali, è necessario gestirla manualmente verificando che ogni richiesta si trovi al momento giusto della procedura, rispondendo di conseguenza e modificando lo stato per accogliere correttamente la richiesta successiva.

> Per "richiesta inviata al bot" si intendono quelle azioni che chiamano in causa il webhook. Quindi un messaggio è una richiesta, così come lo sono premere un *inline button* o un *button*. Per semplicità i termini "richiesta", "messaggio", "comando" e "input" possono essere considerati come sinonimi in questo articolo.
{: .prompt-info }

Per fare un esempio pratico, immagina di voler sviluppare un bot Telegram che chieda il tuo nome, il tuo cognome e il tuo indirizzo email, in questo ordine specifico, uno alla volta. Partendo da un comando `/start`, il bot ti risponde con il messaggio `Invia il tuo nome`, quindi tu invii il tuo nome `Giuseppe`. Quando invii il tuo nome, il file di webhook non sa che ti trovi in ​​questa procedura specifica, ma considera ogni comando come una nuova richiesta sconnessa dalla precedente. Quindi è necessario mantenere manualmente lo stato della procedura e controllarlo ogni volta che una nuova richiesta viene inviata al bot, per verificare se il messaggio inviato è coerente con lo stato specifico in cui si trova il bot, e, infine, aggiornare lo stato. Implementare manualmente questa logica può essere impegnativo.

Per questo motivo ho sviluppato un framework open-source, chiamato [StatefulBot](https://github.com/giuseppetrivi/StatefulBot-framework), grazie al quale gli aspetti principali di questa dinamica vengono gestiti automaticamente.


## Rapida panoramica su StatefulBot
La composizione generale del framework è spiegata nel dettaglio nella [wiki del progetto](https://github.com/giuseppetrivi/StatefulBot-framework/wiki) e non verrà trattata qui. Ma per dare una visione generale, ho riportato un semplice diagramma delle classi che ne evidenzia la struttura. Come si può notare, viene utilizzata un'architettura [MVC (Model-View-Controller)](https://it.wikipedia.org/wiki/Model-view-controller), per separare logicamente tre tipi di entità:
- le entità legate all'interfaccia *(view)*, che nel caso dei bot Telegram riguardano principalmente i messaggi, le keyboard e le inline keyboard
- le entità che modellano i componenti presenti nel database e che, in generale, si interfacciano con eventuali servizi esterni *(model)*
- le entità responsabili dell'esecuzione delle procedure specifiche *(controller)*

![Desktop View](/assets/img/StatefulBot_class_diagram.webp)


## In che modo StatefulBot gestisce gli stati

### Cos'è uno stato
Prima di parlare della parte implementativa, bisogna specificare cos'è uno **stato**. Uno stato è identificato da una stringa e rappresenta il contesto, la prospettiva, che una richiesta in entrata al bot deve assumere. Lo stato è una stringa del tipo `InviaNome`, oppure `InviaNome\InviaCognome` o, ancora, `InviaNome\InviaCognome\InviaEmail`, in cui ogni nome separato da `\` identifica una parte specifica dello stato complessivo e l'ultimo nome, più a destra, identifica lo stato attuale. <br>
Lo stato attuale indica la classe, mentre il resto è rappresentato dal namespace nel file di definizione della classe dello stato attuale, ad esempio:

```php
namespace InviaNome\InviaCognome;

class InviaEmail extends AbstractState {
  /* ... */
}
```

Lo stato determina, quindi, quale classe inizializzare mentre l'input specifico di una richiesta determina quale metodo, quindi quale procedura, eseguire di quello specifico stato e in che modo aggiornarlo per accogliere la richiesta successiva.

> La stringa che identifica lo stato deve essere sempre salvata ed associata all'utente che invia la richiesta. 
{: .prompt-warning }
> Consiglio di salvare lo stato in un campo specifico nella tabella del database usata per mantenere le informazioni degli utenti, ad esempio un campo `state_name`, dato che la cardinalità tra Utente e Stato è appunto di 1:1.
{: .prompt-tip }

### La classe `AbstractState`
A livello implementativo, il cuore del framework è rappresentato dalla classe `AbstractState`. Questa è la classe che deve essere estesa da tutte le classi che fanno parte del *controller* e che rappresentano gli stati e gestiscono, al loro interno, le procedure.

`AbstractState` necessita di due oggetti per essere inizializzata: un oggetto `User`, che è strutturato in modo da interfacciarsi con la tabella per la gestione degli utenti e per la gestione degli stati associati ad essi, e un oggetto `Bot` per gestire le richieste in entrata e in uscita dal bot.

L'unico metodo `public` che può essere invocato dall'esterno della classe `AbstractState` e dalle sue sottoclassi è il metodo `codeToRun()`, che è composto di tre parti:
1. una verifica delle precondizioni
2. l'esecuzione della procedura associata al comando inviato
3. la gestione delle postcondizioni relative al cambio di stato

#### Verifica delle precondizioni
Nella prima parte viene verificato l'input inviato dall'utente al bot. Viene fatta una distinzione tra due tipi di input: quelli *statici* e quelli *dinamici*.

Gli input statici sono i comandi costanti, dei quali si può stabilire a priori l'associazione con una procedura da eseguire. Ad esempio un comando `/start` lo si può associare a priori ad una procedura del tipo `startProcedure()`, che dovrà poi essere implementata nella classe. Queste associazioni, dunque, sono definite staticamente (appunto) nel momento della definizione della sottoclasse nell'array `$valid_static_inputs` che contiene elementi della forma `"comando" => "nomeProcedura"`, dove `"nomeProcedura"` va implementata come `protected function nomeProcedura()` all'interno della classe.

Gli input dinamici invece hanno una struttura più o meno variabile, spesso riconducibile ad un pattern verificabile con delle [espressioni regolari](https://it.wikipedia.org/wiki/Espressione_regolare). Questi vanno definiti manualmente nella funzione `validateDynamicInputs()` e se c'è un match allora va definita la procedura da eseguire assegnando il suo nome all'attributo `$function_to_call`.

Un esempio per illustrare queste implementazioni:
```php
namespace InviaNome\InviaCognome;

class InviaEmail extends AbstractState {
  protected array $valid_static_inputs = [
    "Indietro" => "backProcedure"
  ];

  protected function validateDynamicInputs() {
    $input_text = $this->_Bot->getInputFromChat()->getText();

    $regex = "/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/";
    if (preg_match($regex, $input_text)) {
      $this->function_to_call = "selectEmailProcedure";
      return true;
    }
    return false;
  }


  protected function backProcedure() {
    /* ... */
  }

  protected function selectEmailProcedure() {
    /* ... */
  }
}
```
Le prime associazioni ad essere verificate sono quelle statiche, poi quelle dinamiche. Quindi se siamo nello stato `InviaNome\InviaCognome\InviaEmail` e viene inviato il messaggio `Indietro`, verrà eseguito il codice all'interno della funzione `backProcedure()`. Se, invece, nello stesso stato dovesse essere inviato un indirizzo email corrispondente al pattern `$regex` verrà eseguito il codice all'interno della funzione `selectEmailProcedure()`. Se non viene trovata nessuna associazione allora verrà sollevata un'eccezione.

#### Esecuzione della procedura specifica
Come accennato sopra, una volta trovato un match tra l'input inviato e uno tra gli input statici o dinamici validi per lo stato attuale, verrà eseguita la procedura associata ad esso, il cui nome è salvato nell'attributo `$function_to_call` (questo spiega perché va definito manualmente nel caso degli input dinamici). <br>
Nella definizione della procedura (idealmente alla fine di essa, ma dipende dai casi), va impostato il nome del prossimo stato con la funzione `setNextState($state_name, $state_data)`.

> Il parametro `$state_data` rappresenta un'informazione che si vuole salvare, magari per renderla disponibile al prossimo stato. Non essendo necessaria, ignorerò l'esistenza di questo campo durante il seguito di questo articolo.
{: .prompt-info }

Nella classe `AbstractState` sono definiti diversi metodi per manipolare le stringhe di uno stato, per poi passare i risultati di queste funzioni alla funzione `setNextState`:
- `keepThisState()` imposta come stato quello attuale, per rimanere sempre nello stesso stato.
- `appendNextState($next_state)` prende lo stato attuale ed aggiunge `\$next_state`, in modo da ritornare la stringa dello stato successivo
- `getPreviousState()` prende lo stato attuale e rimuove la parte terminale, ovvero `\StatoAttuale`, in modo da ritornare la stringa dello stato precedente

Possono essere implementati metodi per agevolare ulteriormente l'aggiornamento degli stati in base all'architettura del proprio bot Telegram. In generale, se non viene chiamata la funzione `setNextState($state_name)`, verrà impostato automaticamente lo stato `NULL` (che dovrebbe corrispondere allo stato radice, il primo stato in assoluto, ad esempio un eventuale menu principale).

> Il motivo per cui la decisione sul prossimo stato da impostare va scritta nella procedura è che in una procedura ci possono essere diversi rami di esecuzione, e in base a questi possono essere impostati diversi stati successivi.
{: .prompt-tip }

#### Postcondizioni e cambio di stato
In quest'ultima parte della funzione `codeToRun()` non viene fatto altro che aggiornare lo stato nel database, in base al valore dell'attributo `$state_name` impostato all'interno della procedura tramite la funzione `setNextState` (altrimenti verrà impostato a `NULL`). 


### Esempio finale
[Questo](https://github.com/giuseppetrivi/OBCBot) è un repository che può essere preso come progetto di esempio per l'utilizzo del framework StatefulBot e della logica degli stati.

Invece, riprendendo l'esempio da cui siamo partiti, ora illustrerò una semplice implementazione degli stati. L'esempio del primo paragrafo consisteva in un bot che, una volta avviato con un comando `/start`, chiedesse il nome, il cognome e l'indirizzo email in questo ordine, uno alla volta. Alcune parti dei seguenti snippet saranno solo commentate per semplicità.

Partiamo definendo il primo stato principale `Main` (che può essere visto come lo stato associato al valore `NULL` nel campo `state_name`):
```php
/* file Main.php */

class Main extends AbstractState {
  protected array $valid_static_inputs = [
    "/start" => "startProcedure"
  ];


  protected function startProcedure() {
    /* invia il messaggio "Invia il tuo nome" */

    $this->setNextState("InviaNome");
  }
}
```

Poi vanno definite le altre tre classi, corrispondenti ai tre stati richiesti da questo flusso di comandi:
```php
/* file InviaNome.php */

class InviaNome extends AbstractState {
  protected function validateDynamicInputs() {
    $input_text = $this->_Bot->getInputFromChat()->getText();

    $regex = "/^[A-Za-z ]*/";
    if (preg_match($regex, $input_text)) {
      $this->function_to_call = "selectNameProcedure";
      return true;
    }
    return false;
  }


  protected function selectNameProcedure() {
    /* ... operazioni arbitrarie ... */

    /* invia il messaggio "Invia il tuo cognome" */

    $this->setNextState($this->appendNextState("InviaCognome"));
    //equivalente a $this->setNextState("InviaNome\InviaCognome");
  }
}
```
```php
/* file InviaCognome.php */
namespace InviaNome;

class InviaCognome extends AbstractState {
  protected function validateDynamicInputs() {
    $input_text = $this->_Bot->getInputFromChat()->getText();

    $regex = "/^[A-Za-z ]*/";
    if (preg_match($regex, $input_text)) {
      $this->function_to_call = "selectSurnameProcedure";
      return true;
    }
    return false;
  }


  protected function selectSurnameProcedure() {
    /* ... operazioni arbitrarie ... */

    /* invia il messaggio "Invia il tuo indirizzo email" */

    $this->setNextState($this->appendNextState("InviaEmail"));
    //equivalente a $this->setNextState("InviaNome\InviaCognome\InviaEmail");
  }
}
```
```php
/* file InviaCognome.php */
namespace InviaNome\InviaCognome;

class InviaEmail extends AbstractState {
  protected function validateDynamicInputs() {
    $input_text = $this->_Bot->getInputFromChat()->getText();

    $regex = "/^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/";
    if (preg_match($regex, $input_text)) {
      $this->function_to_call = "selectEmailProcedure";
      return true;
    }
    return false;
  }


  protected function selectEmailProcedure() {
    /* ... operazioni arbitrarie ... */

    $this->setNextState(NULL);
    //per tornare allo stato iniziale, gestito dalla classe Main
  }
}
```

Qui di seguito ho cercato di racchiudere una spiegazione dell'interazione tra utente e bot e del flusso degli stati:
```
UTENTE: "/start"
BOT: 
  prende lo stato associato all'utente (NULL, ovvero Main)
  esegue il metodo startProcedure nella classe Main
  invia il messaggio "Invia il tuo nome"
  modifica lo stato associato all'utente, da NULL a InviaNome

UTENTE: "Giuseppe"
BOT: 
  prende lo stato associato all'utente (InviaNome)
  esegue il metodo selectNameProcedure nella classe InviaNome
  invia il messaggio "Invia il tuo cognome"
  modifica lo stato associato all'utente, da InviaNome a InviaNome\InviaCognome

UTENTE: "Trivisano"
BOT: 
  prende lo stato associato all'utente (InviaNome\InviaCognome)
  esegue il metodo selectSurnameProcedure nella classe InviaNome\InviaCognome (namespace)
  invia il messaggio "Invia il tuo indirizzo email"
  modifica lo stato associato all'utente, da InviaNome\InviaCognome a InviaNome\InviaCognome\InviaEmail

UTENTE: "giuseppetrivisanogt@gmail.com"
BOT: 
  prende lo stato associato all'utente (InviaNome\InviaCognome\InviaEmail)
  esegue il metodo selectEmailProcedure nella classe InviaNome\InviaCognome\InviaEmail (namespace)
  modifica lo stato associato all'utente, da InviaNome\InviaCognome\InviaEmail a NULL (ovvero Main)
```


### Conclusioni
In questo articolo ho illustrato la parte fondamentale del framework StatefulBot e la sua efficacia nella scrittura e nella gestione degli stati. 

In futuro potrebbero esserci miglioramenti all'architettura e un arricchimento delle funzionalità. Nello specifico stavo pensando di rendere ancora più automatica la gestione e la verifica degli input dinamici, in modo da renderla "invisibile" come la validazione degli input statici. Inoltre, stavo pensando di parametrizzare e definire in maniera ordinata i nomi degli stati, in modo da non dover scrivere le loro stringhe identificative a mano.

Se hai suggerimenti o pareri a riguardo, contattami :)