# KreeRequest
A lightweight http request helper for JSON REST APIs

_The name Kree comes from the TV Series Stargate SG-1, where it means something like "Hey!" in the alien language of the Goa'Uld._

## Usage

```swift
import KreeRequest
```

Create an instance of `KreeRequest` and give it an encoder and a decoder:
```swift
let request = KreeRequest(encoder: JSONEncoder(), decoder: JSONDecoder())
```

Optionally give it a logger so that you can see all the data that is sent and received during the request:
```swift
struct MyLogger: Logger {
    func log(_ message: String) {
        print(message)
    }
}

let request = KreeRequest(encoder: JSONEncoder(), decoder: JSONDecoder(), logger: MyLogger())
```

Define a type for the url of the backend that you want to access:
```swift
struct MyBackend: Backend {
    let baseURL = "https://example.com/"
}
```

To perform a request, first create a config for that request.
Provide a method (GET, POST, PUT, etc.), the backend and a path that will be appended to the baseURL of the backend:
```swift
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese")
```

Optionally provide urlParameters:
```swift
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese", urlParameters: ["age":"5"])
```
... and/or http headers:
```swift
let config = KreeRequest.Config(method: .post, backend: MyBackend(), path: "cheese", headers: ["Content-Type": "application/json"])
```

Perform the request:
```swift
try await request.requestJson(config: config)
```

Pass data to the request:
```swift
struct Milk: Encodable {
    var name = ""
}

try await request.requestJson(config: config, json: Milk())
```
The `Milk` object will be encoded as JSON and will be sent in the http body.

Get data back from the request:
```swift
struct Cheese: Decodable {
    let name: String
}

let cheese: Cheese = try await request.requestJson(config: config)
```
The http body from the response will be decoded from JSON to the `Cheese` object.

Optionally provide the Error type for the JSON REST API:
```swift
struct ApiError: Error, Decodable {
    let message: String
}

try await request.requestJson(config: config, apiError: ApiError.self)
```
If the request responds with an error and the body contains JSON encoded information about the error, the error `KreeRequest.Error.apiError(ApiError)` will be thrown, containing the decoded error object.
