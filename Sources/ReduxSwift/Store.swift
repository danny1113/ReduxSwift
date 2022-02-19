//
//  Store.swift
//  
//
//  Created by Danny on 2022/2/18.
//

import Foundation
import Combine



public typealias Reducer<State, Action, Environment> = (inout State, Action, Environment) -> AnyPublisher<Action, Never>?

final public class Store<State, Action, Environment>: ObservableObject {

    @Published public private(set) var state: State
    public var environment: Environment

    private let reducer: Reducer<State, Action, Environment>
    private var cancellables = Set<AnyCancellable>()

    public init(
        state: State,
        reducer: @escaping Reducer<State, Action, Environment>,
        environment: Environment) {
        self.state = state
        self.reducer = reducer
        self.environment = environment
    }

    public func send(_ action: Action) {
        guard let effect = reducer(&state, action, environment) else {
            print("effect is nil.")
            return
        }

        effect
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: send)
            .store(in: &cancellables)
    }

    public func derived<DerivedState, DerivedAction>(
        deriveState: @escaping (State) -> DerivedState,
        deriveAction: @escaping (DerivedAction) -> Action
    ) -> Store<DerivedState, DerivedAction, Environment> where DerivedState: Equatable {
        let store = Store<DerivedState, DerivedAction, Environment> (
            state: deriveState(state),
            reducer: { (_: inout DerivedState, action: DerivedAction, _: Environment) -> AnyPublisher<DerivedAction, Never>? in
                self.send(deriveAction(action))
                return Empty().eraseToAnyPublisher()
            },
            environment: environment
        )
        $state
            .map(deriveState)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &store.$state)
        return store
    }

}
