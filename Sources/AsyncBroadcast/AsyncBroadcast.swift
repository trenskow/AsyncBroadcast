//
// AsyncBroadcast.swift
// 0-bit-games-shared-client-swift
//
// Created by Kristian Trenskow on 2025/04/12
// See license in LICENSE.
//

import Foundation

@MainActor
public class AsyncBroadcast<Element: Sendable> {

	public typealias Stream = AsyncStream<Element>

	private var continuations: [UUID: Stream.Continuation] = [:]

	@MainActor
	private class Sequence: @preconcurrency AsyncSequence {

		public typealias AsyncIterator = Stream.Iterator

		private var onLaunch: (Stream.Continuation) -> Void
		private var onTermination: () -> Void

		init(
			onLaunch: @escaping (Stream.Continuation) -> Void,
			onTermination: @escaping () -> Void
		) {
			self.onLaunch = onLaunch
			self.onTermination = onTermination
		}

		private lazy var stream: Stream = {
			return Stream { continuation in

				self.onLaunch(continuation)

				continuation.onTermination = { _ in
					Task { @MainActor in
						self.onTermination()
					}
				}

			}
		}()

		public func makeAsyncIterator() -> Stream.Iterator {
			return stream.makeAsyncIterator()
		}

	}

	public func values() -> Stream.Iterator {

		let uuid = UUID()

		return Sequence(
			onLaunch: { self.continuations[uuid] = $0 },
			onTermination: { self.continuations.removeValue(forKey: uuid) })
			.makeAsyncIterator()

	}

	public func send(
		_ element: Element
	) {
		for continuation in continuations.values {
			continuation.yield(element)
		}
	}

	public func cancel() {

		continuations.values.forEach { continuation in
			continuation.finish()
		}

		self.continuations = [:]

	}

}

extension AsyncBroadcast {

	public convenience init(
		_ stream: Stream
	) {
		self.init()

		Task { @MainActor in

			for await element in stream {
				self.send(element)
			}

			self.cancel()

		}

	}

}
