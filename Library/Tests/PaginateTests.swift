import XCTest
@testable import Library
import ReactiveCocoa
import Result
@testable import ReactiveExtensions_TestHelpers

final class PaginateTests: TestCase {

  let (newRequest, newRequestObserver) = Signal<Int, NoError>.pipe()
  let (nextPage, nextPageObserver) = Signal<(), NoError>.pipe()
  let requestFromParams: Int -> SignalProducer<[Int], NoError> = { p in .init(value: [p]) }
  let requestFromCursor: Int -> SignalProducer<[Int], NoError> = { c in .init(value: c <= 2 ? [c] : []) }
  let valuesFromEnvelope: [Int] -> [Int] = { $0 }
  let cursorFromEnvelope: [Int] -> Int = { ($0.last ?? 0) + 1 }

  func testEmitsEmptyState_ClearOnNewRequest() {
    let requestFromParams: Int -> SignalProducer<[Int], NoError> = { p in .init(value: []) }
    let requestFromCursor: Int -> SignalProducer<[Int], NoError> = { c in .init(value: []) }

    let (values, loading) = paginate(
      requestFirstPageWith: newRequest,
      requestNextPageWhen: nextPage,
      clearOnNewRequest: true,
      valuesFromEnvelope: valuesFromEnvelope,
      cursorFromEnvelope: cursorFromEnvelope,
      requestFromParams: requestFromParams,
      requestFromCursor: requestFromCursor
    )

    let valuesTest = TestObserver<[Int], NoError>()
    values.observe(valuesTest.observer)
    let loadingTest = TestObserver<Bool, NoError>()
    loading.observe(loadingTest.observer)

    self.newRequestObserver.sendNext(1)
    self.scheduler.advance()

    valuesTest.assertValues([[]])
    loadingTest.assertValues([true, false])

    self.newRequestObserver.sendNext(1)
    self.scheduler.advance()

    valuesTest.assertValues([[]])
    loadingTest.assertValues([true, false, true, false])
  }

  func testEmitsEmptyState_DoNotClearOnNewRequest() {
    let requestFromParams: Int -> SignalProducer<[Int], NoError> = { p in .init(value: []) }
    let requestFromCursor: Int -> SignalProducer<[Int], NoError> = { c in .init(value: []) }

    let (values, loading) = paginate(
      requestFirstPageWith: newRequest,
      requestNextPageWhen: nextPage,
      clearOnNewRequest: false,
      valuesFromEnvelope: valuesFromEnvelope,
      cursorFromEnvelope: cursorFromEnvelope,
      requestFromParams: requestFromParams,
      requestFromCursor: requestFromCursor
    )

    let valuesTest = TestObserver<[Int], NoError>()
    values.observe(valuesTest.observer)
    let loadingTest = TestObserver<Bool, NoError>()
    loading.observe(loadingTest.observer)

    self.newRequestObserver.sendNext(1)
    self.scheduler.advance()

    valuesTest.assertValues([[]])
    loadingTest.assertValues([true, false])

    self.newRequestObserver.sendNext(1)
    self.scheduler.advance()

    valuesTest.assertValues([[]])
    loadingTest.assertValues([true, false, true, false])
  }

  func testPaginateFlow() {
    let (values, loading) = paginate(
      requestFirstPageWith: newRequest,
      requestNextPageWhen: nextPage,
      clearOnNewRequest: true,
      valuesFromEnvelope: valuesFromEnvelope,
      cursorFromEnvelope: cursorFromEnvelope,
      requestFromParams: requestFromParams,
      requestFromCursor: requestFromCursor
    )

    let valuesTest = TestObserver<[Int], NoError>()
    values.observe(valuesTest.observer)
    let loadingTest = TestObserver<Bool, NoError>()
    loading.observe(loadingTest.observer)

    valuesTest.assertDidNotEmitValue("No values emit immediately.")
    loadingTest.assertDidNotEmitValue("No loading happens immediately.")

    // Start request for new set of values.
    self.newRequestObserver.sendNext(1)

    valuesTest.assertDidNotEmitValue("No values emit immediately.")
    loadingTest.assertValues([true], "Loading starts.")

    // Wait enough time for request to finish.
    self.scheduler.advance()

    valuesTest.assertValues([[1]], "Values emit after waiting enough time for request to finish.")
    loadingTest.assertValues([true, false], "Loading stops.")

    // Request next page of values.
    self.nextPageObserver.sendNext()

    valuesTest.assertValues([[1]], "No values emit immediately.")
    loadingTest.assertValues([true, false, true], "Loading starts.")

    // Wait enough time for request to finish.
    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2]], "New page of values emit after waiting enough time.")
    loadingTest.assertValues([true, false, true, false], "Loading stops.")

    // Request next page of results (this page is empty since the last request exhausted the results.)
    self.nextPageObserver.sendNext(())

    valuesTest.assertValues([[1], [1, 2]], "No values emit immediately.")
    loadingTest.assertValues([true, false, true, false, true], "Loading starts.")

    // Wait enough time for request to finish.
    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2]], "No values emit since we exhausted all pages.")
    loadingTest.assertValues([true, false, true, false, true, false], "Loading stops.")

    // Try request for yet another page of values.
    self.nextPageObserver.sendNext(())

    valuesTest.assertValues([[1], [1, 2]], "No values emit immediately.")
    loadingTest.assertValues([true, false, true, false, true, false], "Loading does not start again.")

    // Wait enough time for request to finish.
    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2]], "Still no values emit.")
    loadingTest.assertValues([true, false, true, false, true, false], "Loading did not start or stop again.")

    // Start over with a new request
    self.newRequestObserver.sendNext(0)

    valuesTest.assertValues([[1], [1, 2], []], "Values clear immediately.")
    loadingTest.assertValues([true, false, true, false, true, false, true], "Loading started.")

    // Wait enough time for request to finish.
    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2], [], [0]], "New page of values emits.")
    loadingTest.assertValues([true, false, true, false, true, false, true, false], "Loading finishes.")

  }

  func testPaginate_DoesntClearOnNewRequest() {
    let (values, loading) = paginate(
      requestFirstPageWith: newRequest,
      requestNextPageWhen: nextPage,
      clearOnNewRequest: false,
      valuesFromEnvelope: valuesFromEnvelope,
      cursorFromEnvelope: cursorFromEnvelope,
      requestFromParams: requestFromParams,
      requestFromCursor: requestFromCursor
    )

    let valuesTest = TestObserver<[Int], NoError>()
    values.observe(valuesTest.observer)
    let loadingTest = TestObserver<Bool, NoError>()
    loading.observe(loadingTest.observer)

    valuesTest.assertDidNotEmitValue()
    loadingTest.assertDidNotEmitValue()

    self.newRequestObserver.sendNext(1)

    valuesTest.assertDidNotEmitValue()
    loadingTest.assertValues([true])

    self.scheduler.advance()

    valuesTest.assertValues([[1]])
    loadingTest.assertValues([true, false])

    self.nextPageObserver.sendNext()

    valuesTest.assertValues([[1]])
    loadingTest.assertValues([true, false, true])

    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2]])
    loadingTest.assertValues([true, false, true, false])

    self.newRequestObserver.sendNext(1)

    valuesTest.assertValues([[1], [1, 2]])
    loadingTest.assertValues([true, false, true, false, true])

    self.scheduler.advance()

    valuesTest.assertValues([[1], [1, 2], [1]])
    loadingTest.assertValues([true, false, true, false, true, false])
  }

  func testPaginate_InterleavingOfNextPage() {
    withEnvironment(apiDelayInterval: TestCase.interval) {
      let (values, loading) = paginate(
        requestFirstPageWith: newRequest,
        requestNextPageWhen: nextPage,
        clearOnNewRequest: true,
        valuesFromEnvelope: valuesFromEnvelope,
        cursorFromEnvelope: cursorFromEnvelope,
        requestFromParams: requestFromParams,
        requestFromCursor: requestFromCursor
      )

      let valuesTest = TestObserver<[Int], NoError>()
      values.observe(valuesTest.observer)
      let loadingTest = TestObserver<Bool, NoError>()
      loading.observe(loadingTest.observer)

      self.newRequestObserver.sendNext(1)
      self.scheduler.advanceByInterval(TestCase.interval)

      valuesTest.assertValues([[1]], "Values emit after waiting enough time for request to finish.")
      loadingTest.assertValues([true, false], "Loading started and stopped.")

      self.nextPageObserver.sendNext()
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1]], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true], "Still loading.")

      self.nextPageObserver.sendNext()
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1]], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true, false, true], "Still loading.")

      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1], [1, 2]], "Next page of values emit.")
      loadingTest.assertValues([true, false, true, false, true, false], "Loading stops.")
    }
  }

  func testPaginate_ClearsOnNewRequest_InterleavingOfNewRequestAndNextPage() {
    withEnvironment(apiDelayInterval: TestCase.interval) {
      let (values, loading) = paginate(
        requestFirstPageWith: newRequest,
        requestNextPageWhen: nextPage,
        clearOnNewRequest: true,
        valuesFromEnvelope: valuesFromEnvelope,
        cursorFromEnvelope: cursorFromEnvelope,
        requestFromParams: requestFromParams,
        requestFromCursor: requestFromCursor
      )

      let valuesTest = TestObserver<[Int], NoError>()
      values.observe(valuesTest.observer)
      let loadingTest = TestObserver<Bool, NoError>()
      loading.observe(loadingTest.observer)

      // Request the first page and wait enough time for request to finish.
      self.newRequestObserver.sendNext(1)
      self.scheduler.advanceByInterval(TestCase.interval)

      valuesTest.assertValues([[1]], "Values emit after waiting enough time for request to finish.")
      loadingTest.assertValues([true, false], "Loading started and stopped.")

      // Request the next page and wait only a little bit of time.
      self.nextPageObserver.sendNext()
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1]], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true], "Still loading.")

      // Make a new request for the first page.
      self.newRequestObserver.sendNext(0)

      valuesTest.assertValues([[1], []], "Values clear immediately.")
      loadingTest.assertValues([true, false, true, false, true], "Still loading.")

      // Wait a little bit of time, not enough for request to finish.
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1], []], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true, false, true], "Still loading.")

      // Wait enough time for request to finish.
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1], [], [0]], "Next page of values emit.")
      loadingTest.assertValues([true, false, true, false, true, false], "Loading stops.")
    }
  }

  func testPaginate_DoesNotClearOnNewRequest_InterleavingOfNewRequestAndNextPage() {
    withEnvironment(apiDelayInterval: TestCase.interval) {
      let (values, loading) = paginate(
        requestFirstPageWith: newRequest,
        requestNextPageWhen: nextPage,
        clearOnNewRequest: false,
        valuesFromEnvelope: valuesFromEnvelope,
        cursorFromEnvelope: cursorFromEnvelope,
        requestFromParams: requestFromParams,
        requestFromCursor: requestFromCursor
      )

      let valuesTest = TestObserver<[Int], NoError>()
      values.observe(valuesTest.observer)
      let loadingTest = TestObserver<Bool, NoError>()
      loading.observe(loadingTest.observer)

      // Request the first page and wait enough time for request to finish.
      self.newRequestObserver.sendNext(1)
      self.scheduler.advanceByInterval(TestCase.interval)

      valuesTest.assertValues([[1]], "Values emit after waiting enough time for request to finish.")
      loadingTest.assertValues([true, false], "Loading started and stopped.")

      // Request the next page and wait only a little bit of time.
      self.nextPageObserver.sendNext()
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1]], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true], "Still loading.")

      // Make a new request for the first page.
      self.newRequestObserver.sendNext(0)

      valuesTest.assertValues([[1]], "Does not clear immediately.")
      loadingTest.assertValues([true, false, true, false, true], "Still loading.")

      // Wait a little bit of time, not enough for request to finish.
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1]], "Values don't emit yet.")
      loadingTest.assertValues([true, false, true, false, true], "Still loading.")

      // Wait enough time for request to finish.
      self.scheduler.advanceByInterval(TestCase.interval / 2.0)

      valuesTest.assertValues([[1], [0]], "Next page of values emit.")
      loadingTest.assertValues([true, false, true, false, true, false], "Loading stops.")
    }
  }
}
