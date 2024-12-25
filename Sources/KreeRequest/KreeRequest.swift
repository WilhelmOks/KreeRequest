import Foundation
import AsyncHTTPClient

public struct KreeRequest {
    public enum Error<ApiError: Decodable & Sendable>: Swift.Error, CustomStringConvertible {
        case apiError(status: Int, error: ApiError)
        case apiErrorNotDecodable(status: Int, error: DecodingError)
        case generalError(status: Int?, error: Swift.Error)
        
        public var description: String {
            switch self {
            case .apiError(let status, error: let error):
                "HTTP status: \(status), ApiError: \(error)"
            case .apiErrorNotDecodable(let status, let error): 
                "HTTP status: \(status), ApiError not decodable: \(error)"
            case .generalError(let status, let error):
                if let status {
                    "HTTP status: \(status), General error: \(error)"
                } else {
                    "General error: \(error)"
                }
            }
        }
    }
    
    public struct EmptyError: Decodable, Swift.Error {
        
    }
    
    public enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }
    
    public struct Config {
        public var method: Method
        public var backend: Backend
        public var path: String
        public var urlParameters: [String: String] = [:]
        public var headers: [String: String] = [:]
        public var timeout: TimeInterval
        
        public init(method: KreeRequest.Method, backend: Backend, path: String, urlParameters: [String: String] = [:], headers: [String: String] = [:], timeout: TimeInterval = 30) {
            self.method = method
            self.backend = backend
            self.path = path
            self.urlParameters = urlParameters
            self.headers = headers
            self.timeout = timeout
        }
    }
    
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let logger: Logger?
    
    public init(encoder: JSONEncoder, decoder: JSONDecoder, logger: Logger? = nil) {
        self.encoder = encoder
        self.decoder = decoder
        self.logger = logger
    }
    
    private func makeURLRequest(config: Config, body: Data?) -> (request: HTTPClientRequest, timeout: TimeInterval) {
        let urlQuery = Self.urlEncodedQueryString(from: config.urlParameters)
        let url = config.backend.baseURL + config.path + urlQuery
        var request = HTTPClientRequest(url: url)
        request.method = switch config.method {
            case .get: .GET
            case .put: .PUT
            case .post: .POST
            case .delete: .DELETE
            case .patch: .PATCH
        }
        if let body {
            request.body = .bytes(body, length: .known(Int64(body.count)))
        }
        config.headers.forEach {
            request.headers.add(name: $0.key, value: $0.value)
        }
        return (request, config.timeout)
    }
    
    public static func urlEncodedQueryString(from query: [String: String]) -> String {
        guard !query.isEmpty else { return "" }
        var components = URLComponents()
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let absoluteString = components.url?.absoluteString ?? ""
        let plusCorrection = absoluteString.replacingOccurrences(of: "+", with: "%2b")
        return plusCorrection
    }
    
    @discardableResult private func requestData<ApiError: Decodable & Sendable>(request: HTTPClientRequest, timeout: TimeInterval, apiError: ApiError.Type = EmptyError.self) async throws -> (data: Data, status: Int, headers: [String: String]) {
        do {
            let clientResponse = try await HTTPClient.shared.execute(request, timeout: .seconds(Int64(timeout)))
            let outputData = try await clientResponse.body.data() ?? Data()
            
            if let logger {
                let inputData = try await request.body?.data()
                let logInputString = inputData.flatMap { Self.jsonString(data: $0, prettyPrinted: true) } ?? "(none)"
                let logOutputString = !outputData.isEmpty ? Self.jsonString(data: outputData, prettyPrinted: true) ?? "-" : "(none)"
                let methodString = request.method.rawValue
                logger.log("\(methodString) \(request.url)\nbody: \(logInputString)\nresponse: \(logOutputString)")
            }
                
            let statusCode = Int(clientResponse.status.code)
            
            if (200..<300).contains(statusCode) {
                let headers = Dictionary(uniqueKeysWithValues: clientResponse.headers.map { ($0.name, $0.value) })
                return (outputData, statusCode, headers)
            } else {
                do {
                    let apiError = try decoder.decode(apiError, from: outputData)
                    throw Error<ApiError>.apiError(status: statusCode, error: apiError)
                } catch let decodingError as DecodingError {
                    throw Error<ApiError>.apiErrorNotDecodable(status: statusCode, error: decodingError)
                } catch {
                    throw Error<ApiError>.generalError(status: statusCode, error: error)
                }
            }
        } catch {
            throw Error<ApiError>.generalError(status: nil, error: error)
        }
    }
    
    /// JSON Data to String converter for printing/logging purposes
    public static func jsonString(data: Data, prettyPrinted: Bool) -> String? {
        do {
            let writingOptions: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted] : []
            let decoded: Data?
            if String(data: data, encoding: .utf8) == "null" {
                decoded = nil
            } else if let string = String(data: data, encoding: .utf8), string.first == "\"", string.last == "\"" {
                decoded = data
            } else if let encodedDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                decoded = try JSONSerialization.data(withJSONObject: encodedDict, options: writingOptions)
            } else if let encodedArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] {
                decoded = try JSONSerialization.data(withJSONObject: encodedArray, options: writingOptions)
            } else {
                decoded = nil
            }
            return decoded.flatMap { String(data: $0, encoding: .utf8) }
        } catch {
            return String(data: data, encoding: .utf8)
        }
    }
    
    // MARK: public
    
    public func requestJson<ApiError: Decodable & Sendable>(config: Config, apiError: ApiError.Type = EmptyError.self) async throws {
        let urlRequest = makeURLRequest(config: config, body: nil)
        try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError)
    }
    
    public func requestJson<In: Encodable, ApiError: Decodable & Sendable>(config: Config, json: In, apiError: ApiError.Type = EmptyError.self) async throws {
        let inData = try encoder.encode(json)
        let urlRequest = makeURLRequest(config: config, body: inData)
        try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError)
    }
    
    public func requestJson<Out: Decodable, ApiError: Decodable & Sendable>(config: Config, apiError: ApiError.Type = EmptyError.self) async throws -> Out {
        let urlRequest = makeURLRequest(config: config, body: nil)
        let outData = try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError).data
        return try decoder.decode(Out.self, from: outData)
    }
    
    public func requestJson<In: Encodable, Out: Decodable, ApiError: Decodable & Sendable>(config: Config, json: In, apiError: ApiError.Type = EmptyError.self) async throws -> Out {
        let inData = try encoder.encode(json)
        let urlRequest = makeURLRequest(config: config, body: inData)
        let outData = try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError).data
        return try decoder.decode(Out.self, from: outData)
    }
    
    public func requestJson<ApiError: Decodable & Sendable>(config: Config, string: String, apiError: ApiError.Type = EmptyError.self) async throws {
        let inData = string.data(using: .utf8)
        let urlRequest = makeURLRequest(config: config, body: inData)
        try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError)
    }
    
    public func requestJson<Out: Decodable, ApiError: Decodable & Sendable>(config: Config, string: String, apiError: ApiError.Type = EmptyError.self) async throws -> Out {
        let inData = string.data(using: .utf8)
        let urlRequest = makeURLRequest(config: config, body: inData)
        let outData = try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError).data
        return try decoder.decode(Out.self, from: outData)
    }
    
    public func requestJson<ApiError: Decodable & Sendable>(config: Config, data: Data, apiError: ApiError.Type = EmptyError.self) async throws {
        let urlRequest = makeURLRequest(config: config, body: data)
        try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError)
    }
    
    public func requestJson<Out: Decodable, ApiError: Decodable & Sendable>(config: Config, data: Data, apiError: ApiError.Type = EmptyError.self) async throws -> Out {
        let urlRequest = makeURLRequest(config: config, body: data)
        let outData = try await requestData(request: urlRequest.request, timeout: urlRequest.timeout, apiError: apiError).data
        return try decoder.decode(Out.self, from: outData)
    }
}

private extension HTTPClientRequest.Body {
    func data() async throws -> Data? {
        let buffer = try await collect(upTo: .max)
        return Data(buffer: buffer)
    }
}

private extension HTTPClientResponse.Body {
    func data() async throws -> Data? {
        let buffer = try await collect(upTo: .max)
        return Data(buffer: buffer)
    }
}
