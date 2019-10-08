public struct HTTPClientError: Error {
    public let responseCode: Int
    public let cause: Swift.Error
    
    public enum Category {
        case clientError
        case serverError
    }
    
    public init(responseCode: Int, cause: Swift.Error) {
        self.responseCode = responseCode
        self.cause = cause
    }
    
    public var category: Category {
        switch responseCode {
        case 400...499:
            return .clientError
        default:
            return .serverError
        }
    }
}
