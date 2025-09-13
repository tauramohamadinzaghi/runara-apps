import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PesanPageScreen(),
    );
  }
}

// Define color constants
const Color slate200 = Color(0xFFCBD5E1);
const Color slate400 = Color(0xFF94A3B8);
const Color slate600 = Color(0xFF4B5563);
const Color slate700 = Color(0xFF374151);

class PesanPageScreen extends StatefulWidget {
  const PesanPageScreen({Key? key}) : super(key: key);

  @override
  _PesanPageScreenState createState() => _PesanPageScreenState();
}

// Daftar kontak (tambahkan status online/offline)
class Contact {
  final String name;
  final String status;
  final String imageUrl;

  Contact({
    required this.name,
    required this.status,
    required this.imageUrl,
  });
}

// Daftar kontak
List<Contact> contacts = [
  Contact(name: 'Alex Johnson', status: 'Online', imageUrl: 'https://storage.googleapis.com/a1aa/image/58c4f1bf-85ba-4fb9-b13f-2869b7a469ea.jpg'),
  Contact(name: 'Maria Lee', status: 'Offline', imageUrl: 'https://storage.googleapis.com/a1aa/image/0e59bf0a-5413-4b7b-b7bc-599556c01da1.jpg'),
  Contact(name: 'Shane Martinez', status: 'Online', imageUrl: 'https://storage.googleapis.com/a1aa/image/f1f67ea6-9680-4e6f-a558-a6a3d9ad39f1.jpg'),
  Contact(name: 'John Doe', status: 'Offline', imageUrl: 'https://storage.googleapis.com/a1aa/image/433f9563-a8c0-4fc1-a7f6-fc1dbd13cf36.jpg'),
  Contact(name: 'Jane Smith', status: 'Online', imageUrl: 'https://storage.googleapis.com/a1aa/image/9d9369b9-599e-474c-0cb2-19427b483830.jpg'),
  Contact(name: 'Emily Clark', status: 'Offline', imageUrl: 'https://storage.googleapis.com/a1aa/image/e94908d7-7538-4842-fc64-888c24804ad3.jpg'),
];

bool _isSearching = false; // Control visibility of the search bar
TextEditingController _searchController = TextEditingController(); // Controller for search input
int _selectedTabIndex = 0;

class _PesanPageScreenState extends State<PesanPageScreen> {
  bool _isChatScreenVisible = false; // To toggle between chat list and chat screen
  String _currentChatName = "Shane Martinez"; // To show chat name dynamically
  TextEditingController _controller = TextEditingController();  // Text controller for input
  List<String> _messages = [];  // List to hold chat messages

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(  // Centering the content
          child: Container(
            width: 500,
            height: 800,
            color: const Color(0xFF1e293b),  // Set the background color here
            child: Stack(
              children: [
                // Chat List
                if (!_isChatScreenVisible) _buildChatList(),

                // Chat Screen
                if (_isChatScreenVisible) _buildChatScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Function to send the message
  void _sendMessage() {
    String message = _controller.text.trim();
    if (message.isNotEmpty) {
      setState(() {
        _messages.add(message);  // Add message to the list
        _controller.clear();  // Clear the input field
      });
    }
  }

  // Function to handle search visibility toggle
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
    });
  }

  // Builds the Chat List
  Widget _buildChatList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              IconButton(
                icon: Image.asset('assets/ic_back.png', width: 35, height: 35),
                onPressed: () {
                  setState(() {
                    _isChatScreenVisible = false;
                  });
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Chat',
                style: TextStyle(
                  color: slate200,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: slate400),
                onPressed: _toggleSearch, // Toggle search bar visibility
              ),
            ],
          ),
          const SizedBox(height: 16),
          // If _isSearching is true, show the search bar
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF334155),
                  hintText: 'Cari chat...',
                  hintStyle: const TextStyle(color: slate400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          // Tabs for All Chats, Groups, Contact
          _buildTabs(),
          const SizedBox(height: 16),
          // Recent Contacts
          Expanded(
            child: ListView(
              children: [
                _recentContact('Shane Martinez', '5:30 PM', 'Last message preview...', 'https://storage.googleapis.com/a1aa/image/f1f67ea6-9680-4e6f-a558-a6a3d9ad39f1.jpg'),
                _recentContact('Alex Johnson', '4:45 PM', 'Last message preview...', 'https://storage.googleapis.com/a1aa/image/58c4f1bf-85ba-4fb9-b13f-2869b7a469ea.jpg'),
                _recentContact('Maria Lee', '4:00 PM', 'Last message preview...', 'https://storage.googleapis.com/a1aa/image/0e59bf0a-5413-4b7b-b7bc-599556c01da1.jpg'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the individual contact in the list with name, time, and message preview
  Widget _recentContact(String name, String time, String messagePreview, String imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(imageUrl),
        ),
        title: Text(name, style: const TextStyle(color: slate200, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(messagePreview, style: const TextStyle(color: slate400, fontSize: 12)),
        trailing: Text(time, style: const TextStyle(color: slate400, fontSize: 10)),
        onTap: () {
          setState(() {
            _isChatScreenVisible = true;
            _currentChatName = name;
          });
        },
      ),
    );
  }

  // Builds the tab navigation under Recent - Centered
  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _tabButton('All Chats', index: 0, isSelected: _selectedTabIndex == 0),
        const SizedBox(width: 20),
      ],
    );
  }

  // Builds the individual tab button
  Widget _tabButton(String label, {required int index, bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? slate400 : slate200,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 40,
              color: slate400,
            ),
        ],
      ),
    );
  }


// Builds the Chat Screen
  Widget _buildChatScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header with name, status, and icons
          Row(
            children: [
              // Back Icon
              IconButton(
                icon: Image.asset('assets/ic_back.png', width: 35, height: 35), // Ganti dengan asset ic_back.png
                onPressed: () {
                  setState(() {
                    _isChatScreenVisible = false; // Back to chat list
                  });
                },
              ),
              const SizedBox(width: 8), // Space between icon and text
              // Chat Name and Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,  // Align text to the left
                children: [
                  Text(
                    _currentChatName, // Current chat name
                    style: const TextStyle(
                      color: slate200,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green, // Background color for online status
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Online",  // Status text
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Tunanetra", // Or "Relawan" depending on role
                        style: TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),  // To push phone and info icons to the right
              // Phone and Info Icons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.phone, color: slate400),
                    onPressed: () {
                      // Handle phone icon action
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info, color: slate400),
                    onPressed: () {
                      _showChatSettingsDialog();  // Call the function to show the settings dialog
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chat messages
          Expanded(
            child: ListView(
              children: [
                _message('I\'m meeting a friend here for dinner. How about you? 😁', '5:30 PM', isMe: true),
                _audioMessage('5:45 PM'),
                _message('I\'m doing my homework, but I really need to take a break.', '5:48 PM'),
                _message('On my way home but I needed to stop by the bookstore to buy a text book. 😎', '5:58 PM'),
              ],
            ),
          ),
          // Message Input
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  // + Icon and Emoji Icon
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAddButton,  // Memunculkan pop-up menu
                  ),
                  IconButton(
                    icon: const Icon(Icons.insert_emoticon),
                    onPressed: _showEmojiPopup,  // Memunculkan emoji
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: slate400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send), // Send button
                    onPressed: _sendMessage,  // Use the send function here
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // Function to show the chat settings dialog when the info icon is clicked
  void _showChatSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1e293b),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: 400,  // Adjust the height for the menu
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text("Info kontak", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Info kontak" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_box, color: Colors.blue),
                  title: const Text("Pilih pesan", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Pilih pesan" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_off, color: Colors.blue),
                  title: const Text("Bisukan notifikasi", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Bisukan notifikasi" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_off, color: Colors.blue),
                  title: const Text("Pesan sementara", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Pesan sementara" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.blue),
                  title: const Text("Tutup chat", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Tutup chat" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.red),
                  title: const Text("Laporkan", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Laporkan" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text("Blokir", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Blokir" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: const Text("Bersihkan chat", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Bersihkan chat" action
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text("Hapus chat", style: TextStyle(color: slate200)),
                  onTap: () {
                    // Handle "Hapus chat" action
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // Function to show the "+" button and its popup options
  Widget _showAddButton() {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.add, color: Colors.white),
      onSelected: (value) {
        print("Selected option: $value");
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<int>(
          value: 1,
          child: Row(
            children: const [
              Icon(Icons.insert_drive_file, color: slate200),
              SizedBox(width: 8),
              Text('Dokumen', style: TextStyle(color: slate200)),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 2,
          child: Row(
            children: const [
              Icon(Icons.photo, color: slate200),
              SizedBox(width: 8),
              Text('Foto/Video', style: TextStyle(color: slate200)),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 3,
          child: Row(
            children: const [
              Icon(Icons.camera_alt, color: slate200),
              SizedBox(width: 8),
              Text('Kamera', style: TextStyle(color: slate200)),
            ],
          ),
        ),
      ],
    );
  }

  // Show the emoji picker pop-up when the emoji button is clicked
  void _showEmojiPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1e293b),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: SizedBox(
            height: 160,
            child: GridView.count(
              crossAxisCount: 6,
              children: [
                EmojiButton(emoji: "😀"),
                EmojiButton(emoji: "😁"),
                EmojiButton(emoji: "😂"),
                EmojiButton(emoji: "😎"),
                EmojiButton(emoji: "😍"),
                EmojiButton(emoji: "🥲"),
                EmojiButton(emoji: "😡"),
                EmojiButton(emoji: "👍"),
                EmojiButton(emoji: "🙏"),
                EmojiButton(emoji: "🎉"),
                EmojiButton(emoji: "💡"),
                EmojiButton(emoji: "🔥"),
              ],
            ),
          ),
        );
      },
    );
  }

  // Emoji button for each emoji
  Widget EmojiButton({required String emoji}) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();  // Close the dialog
      },
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  // Builds a message (text)
  Widget _message(String text, String time, {bool isMe = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const Icon(Icons.person, color: slate400),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: 200), // Set a max width for the text container
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF2563eb) : const Color(0xFF1e293b),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.visible,  // Ensure the text wraps when necessary
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the audio message widget
  Widget _audioMessage(String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '02:30',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
