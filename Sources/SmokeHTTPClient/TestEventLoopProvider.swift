// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
//  TestEventLoopProvider.swift
//  SmokeHTTPClient
//

import NIO
import Logging

/**
  Provides a single-threaded `EventLoopGroup` and its `EventLoop`, primarily for testing purposes.
  Automatically shuts down the group in the deinitializer so the lifetime of the provided eventloop is tied to
  the lifetime of this instance.
 */
public class TestEventLoopProvider {
    public let eventLoopGroup: EventLoopGroup
    public let eventLoop: EventLoop
    
    public init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        self.eventLoop = eventLoopGroup.next()
    }
    
    deinit {
        do {
            try self.eventLoopGroup.syncShutdownGracefully()
        } catch {
            let logger = Logger(label: "com.amazon.smoke-http.TestEventLoopProvider")
            
            logger.error("Unable to shutdown test event loop group.")
        }
    }
}
