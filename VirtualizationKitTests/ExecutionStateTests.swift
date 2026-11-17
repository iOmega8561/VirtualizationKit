//
//  Copyright 2026 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Combine
import Foundation
import Testing
import Virtualization
@testable import VirtualizationKit

private struct Boom: LocalizedError {
    var errorDescription: String? { "The hypervisor gave up" }
}

@Suite("Execution state")
struct ExecutionStateTests {

    private let all: [ExecutionState] = [
        .stopped, .running, .paused, .error(error: Boom()), .starting, .pausing,
        .resuming, .stopping, .saving, .restoring, .installing(progress: 0.5)
    ]

    @Test("Every Virtualization state maps by name; .error carries the generic error")
    func mapping() {
        let mapped: [(VZVirtualMachine.State, ExecutionState)] = [
            (.stopped, .stopped), (.running, .running), (.paused, .paused),
            (.error, .error(error: VZKitError.internalVirtualizationError)),
            (.starting, .starting), (.pausing, .pausing), (.resuming, .resuming),
            (.stopping, .stopping), (.saving, .saving), (.restoring, .restoring)
        ]
        for (state, expected) in mapped {
            #expect(ExecutionState(state) == expected)
        }
    }

    @Test("Which actions each state allows")
    func actions() {
        #expect(all.filter(\.allowsStart).map(\.rawValue) == [0, 3])
        #expect(all.filter(\.allowsStop).map(\.rawValue) == [1, 2])
        #expect(all.filter(\.allowsRequestStop) == [.running])
        #expect(all.filter(\.allowsPause) == [.running])
        #expect(all.filter(\.allowsResume) == [.paused])
    }

    @Test("States are hashable and deliberately not codable")
    func conformances() {
        #expect(Set(all).count == all.count)
        #expect(!(ExecutionState.running is any Encodable))
    }
}

@Suite("State of an Apple machine")
@MainActor
struct AppleStateRuleTests {

    private enum Event: CaseIterable { case observedError, delegateError, observedStop }

    private static let specific = ExecutionState.error(error: Boom())
    private static let generic = ExecutionState.error(error: VZKitError.internalVirtualizationError)

    private func permutations(_ events: [Event]) -> [[Event]] {
        events.isEmpty ? [[]] : events.indices.flatMap { index -> [[Event]] in
            var rest = events
            let head = rest.remove(at: index)
            return permutations(rest).map { [head] + $0 }
        }
    }

    /// Applies events the way the coordinator does: observed states through the rules, delegate errors as is.
    private func apply(_ events: [Event], from start: ExecutionState) -> ExecutionState {
        events.reduce(start) { state, event in
            switch event {
            case .delegateError: Self.specific
            case .observedError: AppleStateCoordinator.state(after: state, observing: Self.generic) ?? state
            case .observedStop: AppleStateCoordinator.state(after: state, observing: .stopped) ?? state
            }
        }
    }

    @Test("A failure ends the same way whatever the order of its events (15 orderings)")
    func orderIndependence() {
        var checked = 0
        for mask in 1..<8 {
            let subset = Event.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element)
            let expected = subset.contains(.delegateError) ? Self.specific
                : subset.contains(.observedError) ? Self.generic : .stopped

            for order in permutations(subset) {
                let end = apply(order, from: .running)
                #expect(end == expected, "\(order)")
                // A new lifecycle clears whatever the failure left.
                #expect(AppleStateCoordinator.state(after: end, observing: .starting) == .starting)
                checked += 1
            }
        }
        #expect(checked == 15)
    }

    @Test("An installation ignores other states and ends with .stopped or .error")
    func installation() {
        let installing = ExecutionState.installing(progress: 0.3)
        #expect(AppleStateCoordinator.state(after: installing, observing: .running) == nil)
        #expect(AppleStateCoordinator.state(after: installing, observing: .stopping) == nil)
        #expect(AppleStateCoordinator.state(after: installing, observing: .stopped) == .stopped)
        #expect(AppleStateCoordinator.state(after: installing, observing: Self.generic) == Self.generic)
    }

    @Test("A state equal to the current one is not published again")
    func duplicates() {
        #expect(AppleStateCoordinator.state(after: .running, observing: .running) == nil)
        #expect(AppleStateCoordinator.state(after: .running, observing: .paused) == .paused)
    }

    @Test("The coordinator applies the rules to events delivered through Combine")
    func coordinator() async throws {
        let coordinator = AppleStateCoordinator()
        let states = PassthroughSubject<VZVirtualMachine.State, Never>()
        let errors = PassthroughSubject<Error, Never>()
        coordinator.subscribe(states)
        coordinator.subscribe(errors)

        var published: [ExecutionState] = []
        let subscription = coordinator.statePublisher.sink { published.append($0) }
        defer { subscription.cancel() }

        states.send(.starting)
        states.send(.running)
        try await waitUntil { coordinator.executionState == .running }

        errors.send(Boom())
        states.send(.error)
        states.send(.stopped)
        try await waitUntil { coordinator.executionState == Self.specific }
        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.executionState == Self.specific, "a later .stopped replaced the error")

        // A late subscriber gets the current state at once.
        var late: [ExecutionState] = []
        let lateSubscription = coordinator.statePublisher.sink { late.append($0) }
        defer { lateSubscription.cancel() }
        #expect(late == [Self.specific])

        #expect(published.first == .stopped)
        #expect(published.contains(.running))
    }
}
