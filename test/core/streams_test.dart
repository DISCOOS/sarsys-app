

import 'dart:async';

import 'package:SarSys/core/data/streams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() async {
  test('StreamRequestQueue should add, execute and remove request', () async {
    // Arrange
    final queue = StreamRequestQueue();
    final completer = Completer();
    final command = () async {
      return StreamResult.none();
    };
    final request = StreamRequest(
      execute: command,
      onResult: completer,
    );

    // Act
    final added = queue.add(request);

    // Assert
    expect(added, isTrue, reason: "should add");
    expect(queue.isHead(request.key), isTrue, reason: "should be head");
    expect(queue.contains(request.key), isTrue, reason: "should contain");
    expect(await request.onResult!.future, isNull, reason: "should execute");
    expect(queue.length, 0, reason: "should be empty");
    expect(queue.isEmpty, isTrue, reason: "should be empty");
    expect(queue.isIdle, isFalse, reason: "should be not idle");
    expect(queue.isProcessing, isTrue, reason: "should not processing");

    // Cleanup
    await queue.cancel();
  });

  test('StreamRequestQueue should remove pending request and continue', () async {
    // Arrange
    final queue = StreamRequestQueue();
    final completer = Completer();
    final command = () async {
      return StreamResult.none();
    };
    final request = StreamRequest(
      execute: command,
      onResult: completer,
    );
    queue.add(request);

    // Act
    final removed = queue.remove(request.key);

    // Assert
    expect(removed, isTrue, reason: "should remove");
    expect(queue.length, 0, reason: "should be empty");
    expect(queue.isEmpty, isTrue, reason: "should be empty");
    expect(queue.isIdle, isFalse, reason: "should be not idle");
    expect(queue.isProcessing, isTrue, reason: "should not processing");
    expect(queue.isCurrent(request.key), isFalse, reason: "should be current");

    // Cleanup
    await queue.cancel();
  });

  test('StreamRequestQueue should clear all pending request and continue', () async {
    // Arrange
    final queue = StreamRequestQueue();
    final command = () async {
      return StreamResult.none();
    };

    final requests = List.generate(
      10,
      (index) => StreamRequest(
        execute: command,
        onResult: Completer(),
      ),
    );
    requests.forEach(queue.add);
    final first = requests.first;
    expect(await first.onResult!.future, isNull, reason: "should execute");

    // Act
    final removed = queue.clear();

    // Assert
    expect(removed.length, 9, reason: "should remove 9");
    expect(queue.length, 0, reason: "should be empty");
    expect(queue.isEmpty, isTrue, reason: "should be empty");
    expect(queue.isIdle, isFalse, reason: "should be not idle");
    expect(queue.isProcessing, isTrue, reason: "should not processing");

    // Cleanup
    await queue.cancel();
  });

  test('StreamRequestQueue should clear all pending request and stop', () async {
    // Arrange
    final queue = StreamRequestQueue();

    final requests = List.generate(
      10,
      (index) => StreamRequest(
        key: '$index',
        execute: () async {
          // Simulate long running
          // command to test if this
          // hangs processing.
          return Future<StreamResult>.delayed(
            // First item has zero delay
            Duration(hours: index),
            () => StreamResult.none(),
          );
        },
        onResult: Completer(),
      ),
    );
    requests.forEach(queue.add);

    // Wait for first delayed command (index == 1)
    while (queue.current == null || queue.current!.key != '1') {
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Cancel pending commands
    final removed = await queue.cancel();

    // Assert
    expect(removed.length, 9, reason: "should remove 9");
    expect(queue.length, 0, reason: "should be empty");
    expect(queue.isEmpty, isTrue, reason: "should be empty");
    expect(queue.isIdle, isTrue, reason: "should be be idle");
    expect(queue.isProcessing, isFalse, reason: "should not be processing");

    // Cleanup
    await queue.cancel();
  });

  test('StreamRequestQueue should stop processing requests', () async {
    // Arrange
    final queue = StreamRequestQueue();

    final requests = List.generate(
      10,
      (index) => StreamRequest(
        key: '$index',
        execute: () async {
          // Simulate long running
          // command to test if this
          // hangs processing.
          return Future<StreamResult>.delayed(
            // First item has zero delay
            Duration(hours: index),
            () => StreamResult.none(),
          );
        },
        onResult: Completer(),
      ),
    );
    requests.forEach(queue.add);

    // Wait for first delayed command (index == 1)
    while (queue.current == null || queue.current!.key != '1') {
      await Future.delayed(Duration(milliseconds: 100));
    }

    // Stop processing commands
    queue.stop();

    // Assert
    expect(queue.length, 9, reason: "should be 9 left");
    expect(queue.isNotEmpty, isTrue, reason: "should not be empty");
    expect(queue.isIdle, isTrue, reason: "should be idle");
    expect(queue.isProcessing, isFalse, reason: "should not be processing");

    // Cleanup
    await queue.cancel();
  });

  test('StreamRequestQueue should resume processing requests', () async {
    // Arrange
    final queue = StreamRequestQueue();
    final command = () async {
      return StreamResult.none();
    };

    final requests = List.generate(
      10,
      (index) => StreamRequest(
        execute: command,
        onResult: Completer(),
      ),
    );
    requests.forEach(queue.add);

    // Wait for first command to be processed before stopping
    final first = requests.first;
    expect(await first.onResult!.future, isNull, reason: "should execute");
    queue.stop();

    // Act
    final started = queue.start();

    // Wait for queue to empty
    await queue.onEvent().where((event) => event is StreamQueueIdle).first;

    // Assert
    expect(started, isTrue, reason: "should be added");
    expect(queue.isIdle, isTrue, reason: "should be idle");
    expect(queue.isEmpty, isTrue, reason: "should be empty");
    expect(queue.isProcessing, isFalse, reason: "should not be processing");

    // Cleanup
    await queue.cancel();
  });
}
