//
// AsyncBroadcast.swift
// 0-bit-games-shared-client-swift
//
// Created by Kristian Trenskow on 2025/04/12
// See license in LICENSE.
//

import Foundation

public final class AsyncBroadcast<Element: Sendable>: Sendable {

	public typealias Stream = AsyncStream<Element>

	public final class Sequence: AsyncSequence, Sendable {

		public typealias AsyncIterator = Stream.Iterator

		private let onLaunch: @Sendable (Stream.Continuation) -> Void
		private let onTermination: @Sendable () -> Void

		init(
			onLaunch: @escaping @Sendable (Stream.Continuation) -> Void,
			onTermination: @escaping @Sendable () -> Void
		) {
			self.onLaunch = onLaunch
			self.onTermination = onTermination
		}

		public func makeAsyncIterator() -> Stream.Iterator {

			return Stream { continuation in

				self.onLaunch(continuation)

				continuation.onTermination = { _ in
					Task {
						self.onTermination()
					}
				}

			}.makeAsyncIterator()

		}

	}

	@MainActor
	private var continuations: [UUID: Stream.Continuation] = [:]

	public init() { }

	public func sequence() -> Sequence {

		let uuid = UUID()

		return Sequence(
			onLaunch: { continuation in
				Task { @MainActor in
					self.continuations[uuid] = continuation
				}
			},
			onTermination: {
				Task { @MainActor in
					self.continuations.removeValue(forKey: uuid)
				}
			})

	}

	@MainActor
	public func send(
		_ element: Element
	) {
		for continuation in continuations.values {
			continuation.yield(element)
		}
	}

	@MainActor
	public func cancel() {

		continuations.values.forEach { continuation in
			continuation.finish()
		}

		self.continuations = [:]

	}

}

extension AsyncBroadcast {

	@MainActor
	public convenience init<T: AsyncSequence>(
		sequence: T
	) where T.Element == Element, T.Failure == Never {
		self.init()

		Task { @MainActor in

			for await element in sequence {
				self.send(element)
			}

			self.cancel()

		}

	}

}
