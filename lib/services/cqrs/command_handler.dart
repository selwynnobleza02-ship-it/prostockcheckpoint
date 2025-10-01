import 'dart:async';
import 'package:prostock/services/event_sourcing/event_store.dart';
import 'package:prostock/utils/error_logger.dart';
import 'package:uuid/uuid.dart';

/// Command handler for CQRS pattern
class CommandHandler {
  final EventStore _eventStore;
  final Map<String, CommandHandlerFunction<Command>> _handlers = {};

  CommandHandler(this._eventStore);

  /// Register a command handler
  void registerHandler<T extends Command>(
    String commandType,
    CommandHandlerFunction<T> handler,
  ) {
    _handlers[commandType] = handler as CommandHandlerFunction<Command>;
    ErrorLogger.logInfo(
      'Command handler registered for $commandType',
      context: 'CommandHandler.registerHandler',
    );
  }

  /// Handle a command
  Future<CommandResult> handle(Command command) async {
    try {
      final handler = _handlers[command.runtimeType.toString()];
      if (handler == null) {
        throw Exception('No handler registered for ${command.runtimeType}');
      }

      ErrorLogger.logInfo(
        'Handling command ${command.runtimeType}',
        context: 'CommandHandler.handle',
        metadata: {'commandId': command.id},
      );

      // Execute command handler
      final result = await handler(command);

      // Emit events if command was successful
      if (result.isSuccess && result.events.isNotEmpty) {
        for (final event in result.events) {
          await _eventStore.appendEvent(event);
        }
      }

      return result;
    } catch (e) {
      ErrorLogger.logError(
        'Failed to handle command ${command.runtimeType}',
        error: e,
        context: 'CommandHandler.handle',
      );
      return CommandResult.failure('Command handling failed: ${e.toString()}');
    }
  }

  /// Handle multiple commands as a transaction
  Future<CommandResult> handleTransaction(List<Command> commands) async {
    try {
      final results = <CommandResult>[];
      final allEvents = <DomainEvent>[];

      for (final command in commands) {
        final result = await handle(command);
        results.add(result);

        if (!result.isSuccess) {
          // If any command fails, return failure
          return CommandResult.failure(
            'Transaction failed at command ${command.runtimeType}: ${result.error}',
          );
        }

        allEvents.addAll(result.events);
      }

      return CommandResult.success(allEvents);
    } catch (e) {
      ErrorLogger.logError(
        'Failed to handle command transaction',
        error: e,
        context: 'CommandHandler.handleTransaction',
      );
      return CommandResult.failure('Transaction failed: ${e.toString()}');
    }
  }
}

/// Base command interface
abstract class Command {
  final String id;
  final DateTime timestamp;

  Command({String? id, DateTime? timestamp})
    : id = id ?? const Uuid().v4(),
      timestamp = timestamp ?? DateTime.now();
}

/// Command handler function type
typedef CommandHandlerFunction<T extends Command> =
    Future<CommandResult> Function(T command);

/// Result of command execution
class CommandResult {
  final bool isSuccess;
  final String? error;
  final List<DomainEvent> events;

  CommandResult._({
    required this.isSuccess,
    this.error,
    this.events = const [],
  });

  factory CommandResult.success([List<DomainEvent> events = const []]) {
    return CommandResult._(isSuccess: true, events: events);
  }

  factory CommandResult.failure(String error) {
    return CommandResult._(isSuccess: false, error: error);
  }
}

/// Specific command implementations
class CreateSaleCommand extends Command {
  final String customerId;
  final List<Map<String, dynamic>> items;
  final String paymentMethod;
  final String userId;

  CreateSaleCommand({
    required this.customerId,
    required this.items,
    required this.paymentMethod,
    required this.userId,
    super.id,
    super.timestamp,
  });
}

class CreateCreditPaymentCommand extends Command {
  final String customerId;
  final double amount;
  final String notes;
  final String userId;

  CreateCreditPaymentCommand({
    required this.customerId,
    required this.amount,
    required this.notes,
    required this.userId,
    super.id,
    super.timestamp,
  });
}

class UpdateStockCommand extends Command {
  final String productId;
  final int quantity;
  final String reason;

  UpdateStockCommand({
    required this.productId,
    required this.quantity,
    required this.reason,
    super.id,
    super.timestamp,
  });
}
