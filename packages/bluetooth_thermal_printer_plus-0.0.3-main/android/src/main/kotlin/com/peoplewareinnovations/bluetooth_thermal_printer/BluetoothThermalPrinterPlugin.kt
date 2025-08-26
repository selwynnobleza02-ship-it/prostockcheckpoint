package com.peoplewareinnovations.bluetooth_thermal_printer

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.util.Log
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.io.OutputStream
import java.util.*

private const val TAG = "BluetoothThermalPrinter"
private var outputStream: OutputStream? = null
private lateinit var mac: String

class BluetoothThermalPrinterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var state: String
    private var activity: Activity? = null
    
    // Përdorim SupervisorJob për menaxhimin më të mirë të coroutine-ave
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "bluetooth_thermal_printer_plus")
        channel.setMethodCallHandler(this)
        this.context = flutterPluginBinding.applicationContext
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "getBatteryLevel" -> {
                val batteryLevel = getBatteryLevel()
                if (batteryLevel != -1) {
                    result.success(batteryLevel)
                } else {
                    result.error("UNAVAILABLE", "Battery level not available.", null)
                }
            }
            "BluetoothStatus" -> {
                val isEnabled = isBluetoothEnabled()
                result.success(isEnabled.toString())
            }
            "connectionStatus" -> {
                checkConnectionStatus(result)
            }
            "connectPrinter" -> {
                val printerMAC = call.arguments.toString()
                if (printerMAC.isNotEmpty()) {
                    mac = printerMAC
                    connectToPrinter(result)
                } else {
                    result.success("false")
                }
            }
            "disconnectPrinter" -> {
                disconnectFromPrinter(result)
            }
            "writeBytes" -> {
                val bytesList = call.arguments as? List<Int>
                if (bytesList != null) {
                    writeBytes(bytesList, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid byte array", null)
                }
            }
            "printText" -> {
                val text = call.arguments.toString()
                printText(text, result)
            }
            "bluetothLinked" -> {
                val linkedDevices = getLinkedDevices()
                result.success(linkedDevices)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getBatteryLevel(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = ContextWrapper(context.applicationContext)
                .registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            intent?.let {
                (it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100) / 
                it.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            } ?: -1
        }
    }

    private fun isBluetoothEnabled(): Boolean {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter
        return bluetoothAdapter?.isEnabled == true
    }

    private fun hasBluetoothPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == 
                PackageManager.PERMISSION_GRANTED
        } else {
            ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH) == 
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun checkConnectionStatus(result: Result) {
        outputStream?.let { stream ->
            try {
                stream.write(" ".toByteArray())
                result.success("true")
            } catch (e: IOException) {
                outputStream = null
                showToast("Device was disconnected, reconnect")
                result.success("false")
            }
        } ?: result.success("false")
    }

    private fun connectToPrinter(result: Result) {
        if (!hasBluetoothPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        pluginScope.launch {
            if (outputStream == null) {
                try {
                    outputStream = establishConnection()
                    result.success(state)
                } catch (e: Exception) {
                    Log.e(TAG, "Connection failed", e)
                    result.success("false")
                }
            } else {
                result.success("true")
            }
        }
    }

    private fun disconnectFromPrinter(result: Result) {
        pluginScope.launch {
            try {
                closeConnection()
                result.success("true")
            } catch (e: Exception) {
                Log.e(TAG, "Disconnection failed", e)
                result.success("false")
            }
        }
    }

    private fun writeBytes(bytesList: List<Int>, result: Result) {
        outputStream?.let { stream ->
            try {
                val bytes = bytesList.map { it.toByte() }.toByteArray()
                stream.write(bytes)
                result.success("true")
            } catch (e: IOException) {
                outputStream = null
                showToast("Device was disconnected, reconnect")
                result.success("false")
            }
        } ?: result.success("false")
    }

    private fun printText(stringArrived: String, result: Result) {
        outputStream?.let { stream ->
            try {
                val (size, text) = parseTextInput(stringArrived)
                
                stream.apply {
                    write(PrinterCommands.size[0])
                    write(PrinterCommands.cancelar_chino)
                    write(PrinterCommands.caracteres_escape)
                    write(PrinterCommands.size[size])
                    write(text.toByteArray(charset("iso-8859-1")))
                }
                result.success("true")
            } catch (e: IOException) {
                outputStream = null
                showToast("Device was disconnected, reconnect")
                result.success("false")
            }
        } ?: result.success("false")
    }

    private fun parseTextInput(input: String): Pair<Int, String> {
        val parts = input.split("//")
        return if (parts.size > 1) {
            val size = parts[0].toIntOrNull()?.coerceIn(1, 5) ?: 2
            Pair(size, parts[1])
        } else {
            Pair(2, input)
        }
    }

    private suspend fun establishConnection(): OutputStream? {
        state = "false"
        return withContext(Dispatchers.IO) {
            if (!hasBluetoothPermissions()) {
                Log.e(TAG, "Bluetooth permissions not granted")
                return@withContext null
            }

            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val bluetoothAdapter = bluetoothManager.adapter

            if (bluetoothAdapter?.isEnabled != true) {
                Log.e(TAG, "Bluetooth adapter not enabled")
                return@withContext null
            }

            try {
                val bluetoothDevice = bluetoothAdapter.getRemoteDevice(mac)
                val bluetoothSocket = bluetoothDevice.createRfcommSocketToServiceRecord(
                    UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                )
                
                bluetoothAdapter.cancelDiscovery()
                bluetoothSocket.connect()
                
                if (bluetoothSocket.isConnected) {
                    state = "true"
                    bluetoothSocket.outputStream
                } else {
                    state = "false"
                    bluetoothSocket.close()
                    null
                }
            } catch (e: Exception) {
                state = "false"
                Log.e(TAG, "Connection failed: ${e.message}")
                null
            }
        }
    }

    private suspend fun closeConnection() {
        withContext(Dispatchers.IO) {
            try {
                outputStream?.close()
                outputStream = null
                state = "false"
                Log.d(TAG, "Disconnected successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Error during disconnection: ${e.message}")
            }
        }
    }

    private fun getLinkedDevices(): List<String> {
        if (!hasBluetoothPermissions()) {
            return emptyList()
        }

        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter

        return bluetoothAdapter?.bondedDevices?.map { device ->
            "${device.name}#${device.address}"
        } ?: emptyList()
    }

    private fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        pluginScope.cancel()
    }

    object PrinterCommands {
        val enter = "\n".toByteArray()
        val resetear_impresora = byteArrayOf(0x1b, 0x40, 0x0a)
        val cancelar_chino = byteArrayOf(0x1C, 0x2E)
        val caracteres_escape = byteArrayOf(0x1B, 0x74, 0x10)

        val size = arrayOf(
            byteArrayOf(0x1d, 0x21, 0x00), // La fuente no se agranda 0
            byteArrayOf(0x1b, 0x4d, 0x01), // Fuente ASCII comprimida 1
            byteArrayOf(0x1b, 0x4d, 0x00), // Fuente estándar ASCII 2
            byteArrayOf(0x1d, 0x21, 0x11), // Altura doblada 3
            byteArrayOf(0x1d, 0x21, 0x22), // Altura doblada 4
            byteArrayOf(0x1d, 0x21, 0x33)  // Altura doblada 5
        )

        // Konstantet e tjera për kompatibilitet
        const val HT: Byte = 9
        const val LF: Byte = 10
        const val CR: Byte = 13
        const val ESC: Byte = 27
        const val DLE: Byte = 16
        const val GS: Byte = 29
        const val FS: Byte = 28
        const val STX: Byte = 2
        const val US: Byte = 31
        const val CAN: Byte = 24
        const val CLR: Byte = 12
        const val EOT: Byte = 4

        val INIT = byteArrayOf(27, 64)
        val FEED_LINE = byteArrayOf(10)
        val SELECT_FONT_A = byteArrayOf(20, 33, 0)
        val SET_BAR_CODE_HEIGHT = byteArrayOf(29, 104, 100)
        val PRINT_BAR_CODE_1 = byteArrayOf(29, 107, 2)
        val SEND_NULL_BYTE = byteArrayOf(0)
        val SELECT_PRINT_SHEET = byteArrayOf(27, 99, 48, 2)
        val FEED_PAPER_AND_CUT = byteArrayOf(29, 86, 66, 0)
        val SELECT_CYRILLIC_CHARACTER_CODE_TABLE = byteArrayOf(27, 116, 17)
        val SELECT_BIT_IMAGE_MODE = byteArrayOf(27, 42, 33, -128, 0)
        val SET_LINE_SPACING_24 = byteArrayOf(27, 51, 24)
        val SET_LINE_SPACING_30 = byteArrayOf(27, 51, 30)
        val TRANSMIT_DLE_PRINTER_STATUS = byteArrayOf(16, 4, 1)
        val TRANSMIT_DLE_OFFLINE_PRINTER_STATUS = byteArrayOf(16, 4, 2)
        val TRANSMIT_DLE_ERROR_STATUS = byteArrayOf(16, 4, 3)
        val TRANSMIT_DLE_ROLL_PAPER_SENSOR_STATUS = byteArrayOf(16, 4, 4)
        val ESC_FONT_COLOR_DEFAULT = byteArrayOf(27, 114, 0)
        val FS_FONT_ALIGN = byteArrayOf(28, 33, 1, 27, 33, 1)
        val ESC_ALIGN_LEFT = byteArrayOf(27, 97, 0)
        val ESC_ALIGN_RIGHT = byteArrayOf(27, 97, 2)
        val ESC_ALIGN_CENTER = byteArrayOf(27, 97, 1)
        val ESC_CANCEL_BOLD = byteArrayOf(27, 69, 0)
        val ESC_HORIZONTAL_CENTERS = byteArrayOf(27, 68, 20, 28, 0)
        val ESC_CANCLE_HORIZONTAL_CENTERS = byteArrayOf(27, 68, 0)
        val ESC_ENTER = byteArrayOf(27, 74, 64)
        val PRINTE_TEST = byteArrayOf(29, 40, 65)
    }
}