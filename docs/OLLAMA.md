# Ollama, other servers and model profiles

## Ollama (default)

aic talks to `http://localhost:11434`, or to `$env:OLLAMA_HOST`, or to `-OllamaUrl`. If the server is not running and `ollama` is installed, aic offers to start it (`-StartOllama` does it without asking; only for a server on this machine). Install a model with `ollama pull <name>`; `-Model` tab-completes installed names. `-Unload` frees the model's memory when aic finishes.

## OpenAI-compatible servers (LM Studio, llama.cpp server, ...)

```powershell
aic -Provider openai-compatible -OllamaUrl http://localhost:1234
```

or `"provider": "openai-compatible"` in `.aic.json`. Models come from `/v1/models` and answers are streamed from `/v1/chat/completions`. With no `-Model`, the first non-embedding model the server offers is used. The default address for this provider is `http://localhost:1234` (`OLLAMA_HOST` applies to Ollama only). An API key, if your server needs one, goes in the environment variable `AIC_API_KEY` and is sent as a Bearer token; it is never printed or stored. Ollama-only features (auto-start, capability and context probing, `-Unload`) are skipped.

aic never talks to a cloud service unless **you** point `-OllamaUrl` at one. A server that is not on this machine triggers a warning, because your diff is then sent there (and over plain http, unencrypted).

## Model profiles

`-Profile fast|balanced|quality` (or `"profile"` in `.aic.json`) picks from the models that are installed:

* **fast**: the smallest sensible model (at least about 1.5B parameters)
* **balanced**: the model closest to 7B parameters; a coder model wins a tie
* **quality**: the largest model up to 34B parameters. A bigger model is not assumed to be better: a 70B model that does not fit in memory is slower and no more useful for a commit message.

Parameter counts come from the model name (`qwen2.5-coder:7b`) or are estimated from the file size. Embedding models are never chosen. Precedence: typed `-Model` > typed `-Profile` > configured `model` > configured `profile` > built-in default. `aic -ListModels` shows what each profile would pick. These are heuristics based on name and size; aic does not measure speed or quality, and it does not know how much memory you have.

## Reliability behaviour

* **Retries**: connection refused or dropped, a stream that closes before the model sends anything, and HTTP 502/503/504 are retried twice with a short back-off. Timeouts, 4xx errors and "model not found" are not. A retry only repeats the generation request, never a git operation.
* **Incomplete answers**: an answer cut off at the token limit, a stream that ends without the model reporting it finished, or malformed stream lines are shown as format problems. `-Yes` will not commit such a message (exit 3).
* **Context window**: for Ollama, `num_ctx` is never larger than the model's real context length (read from the server). If prompt plus answer would not fit, the diff is shortened and you are told. `-NumCtx`, `-NumPredict`, `-MaxChars`, `-Temperature`, `-KeepAlive` and `-TimeoutSec` are in the [parameter reference](PARAMETERS.md).
* **Proxies**: a proxy set in the environment is not used for a server on this machine.
* **Thinking models** (qwen3, deepseek-r1 ...) are called with thinking switched off, because reasoning would consume the whole token budget; a model that only thinks is reported instead of committed.
* **First-token latency** and tokens per second (when the server reports them) are shown under the message.

## Choosing a model

* Commit messages are short: a 3B to 7B coder model is usually enough; `-Profile balanced` is a good start.
* Reviews (`-Review`) need more context and more reasoning: try `-Profile quality` if you have the memory.
* If the diff is large, a model with a bigger context window matters more than more parameters. aic tells you when it had to shorten the diff.
