# AsyncBroadcast

Tool for broadcasting values asynchronously in Swift.

## Usage

````Swift
import Foundation
import AsyncBroadcast

let broadcaster = AsyncBroadcast<String>();

Task {
	for await value in broadcaster.values() {
		print(value)
	}
}

Task {
	for await value in broadcaster.values() {
		print(value)
	}
}

Task {
	broadcaster.send("Hello")
	broadcaster.send("World!")
}

// Output
// Hello
// Hello
// World
// World
````

# License

See LICENSE for license
