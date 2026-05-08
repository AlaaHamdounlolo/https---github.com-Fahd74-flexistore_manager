import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../../core/native_bridge.dart';
import '../../core/ffi_helpers.dart';

typedef AddClientNative = Int32 Function(
    Int32 userId, 
    Pointer<Utf8> name, 
    Pointer<Utf8> phone,
    Pointer<Utf8> email,
    Pointer<Utf8> address,
    Pointer<Utf8> notes
);
typedef AddClientDart = int Function(
    int userId, 
    Pointer<Utf8> name, 
    Pointer<Utf8> phone,
    Pointer<Utf8> email,
    Pointer<Utf8> address,
    Pointer<Utf8> notes
);

typedef UpdateClientNative = Int32 Function(
    Int32 userId,
    Int32 clientId,
    Pointer<Utf8> name, 
    Pointer<Utf8> phone,
    Pointer<Utf8> email,
    Pointer<Utf8> address,
    Pointer<Utf8> notes
);
typedef UpdateClientDart = int Function(
    int userId,
    int clientId,
    Pointer<Utf8> name, 
    Pointer<Utf8> phone,
    Pointer<Utf8> email,
    Pointer<Utf8> address,
    Pointer<Utf8> notes
);

typedef DeleteClientNative = Int32 Function(Int32 userId, Int32 clientId);
typedef DeleteClientDart = int Function(int userId, int clientId);

typedef GetAllClientsNative = Pointer<Utf8> Function(Int32 userId);
typedef GetAllClientsDart = Pointer<Utf8> Function(int userId);

class ClientsFFI {
  static final ClientsFFI instance = ClientsFFI._internal();
  ClientsFFI._internal() {
    bindFunctions();
  }

  late AddClientDart _addClient;
  late UpdateClientDart _updateClient;
  late DeleteClientDart _deleteClient;
  late GetAllClientsDart _getAllClients;

  void bindFunctions() {
    final lib = NativeBridge().lib;
    _addClient = lib.lookupFunction<AddClientNative, AddClientDart>('add_client');
    _updateClient = lib.lookupFunction<UpdateClientNative, UpdateClientDart>('update_client');
    _deleteClient = lib.lookupFunction<DeleteClientNative, DeleteClientDart>('delete_client');
    _getAllClients = lib.lookupFunction<GetAllClientsNative, GetAllClientsDart>('get_all_clients');
  }

  int addClient({
    required int userId,
    required String name,
    required String phone,
    String email = "",
    String address = "",
    String notes = "",
  }) {
    final pName = toNativeUtf8(name);
    final pPhone = toNativeUtf8(phone);
    final pEmail = toNativeUtf8(email);
    final pAddress = toNativeUtf8(address);
    final pNotes = toNativeUtf8(notes);

    try {
      return _addClient(userId, pName, pPhone, pEmail, pAddress, pNotes);
    } finally {
      calloc.free(pName);
      calloc.free(pPhone);
      calloc.free(pEmail);
      calloc.free(pAddress);
      calloc.free(pNotes);
    }
  }

  int updateClient({
    required int userId,
    required int clientId,
    required String name,
    required String phone,
    String email = "",
    String address = "",
    String notes = "",
  }) {
    final pName = toNativeUtf8(name);
    final pPhone = toNativeUtf8(phone);
    final pEmail = toNativeUtf8(email);
    final pAddress = toNativeUtf8(address);
    final pNotes = toNativeUtf8(notes);

    try {
      return _updateClient(userId, clientId, pName, pPhone, pEmail, pAddress, pNotes);
    } finally {
      calloc.free(pName);
      calloc.free(pPhone);
      calloc.free(pEmail);
      calloc.free(pAddress);
      calloc.free(pNotes);
    }
  }

  int deleteClient({required int userId, required int clientId}) {
    return _deleteClient(userId, clientId);
  }

  String getAllClients(int userId) {
    final ptr = _getAllClients(userId);
    return parseJsonAndFree(ptr);
  }
}