# KreeRequest
A lightweight http request helper for JSON REST APIs

_The name Kree comes from the TV Series Stargate SG-1, where it means something like "Hey!" in the alien language of the Goa'Uld._

## Usage

`import KreeRequest`

Create an instance of `KreeRequest`and give it an encoder and a decoder:
```
let request = KreeRequest(encoder: JSONEncoder(), decoder: JSONDecoder())
```

Optionally you can give it a logger so that you can see all the data that is sent and received during the request:
```
let request = KreeRequest(encoder: JSONEncoder(), decoder: JSONDecoder(), logger: MyLogger())
```

Define a struct for the url of the backend that you want to access:
```
struct MyBackend: Backend {
    let baseURL = "https://example.com/"
}
```

To perform a request, first create a config for that request.
Provide a method (GET, POST, PUT, etc.), the backend and a path that will be appended to the baseURL of the backend:
```
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese")
```

Optionally provide urlParameters:
```
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese", urlParameters: ["age":"5"])
```
... and/or http headers:
```
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese", headers: ["Content-Type": "application/json"])
```
