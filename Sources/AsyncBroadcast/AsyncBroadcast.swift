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

	@MainActor
	public class Sequence: @preconcurrency AsyncSequence {

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

	private var continuations: [UUID: Stream.Continuation] = [:]

	public init() { }

	public func sequence() -> Sequence {

		let uuid = UUID()

		return Sequence(
			onLaunch: { self.continuations[uuid] = $0 },
			onTermination: { self.continuations.removeValue(forKey: uuid) })

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
