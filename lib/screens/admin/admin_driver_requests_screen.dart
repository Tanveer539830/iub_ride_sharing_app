import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iub_ride_sharing_app/constants/app_colors.dart';
import 'admin_driver_detail_screen.dart';

class AdminDriverRequestsScreen extends StatefulWidget {
  const AdminDriverRequestsScreen({super.key});

  @override
  State<AdminDriverRequestsScreen> createState() => _AdminDriverRequestsScreenState();
}

class _AdminDriverRequestsScreenState extends State<AdminDriverRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Recent";
    final dt = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return "${diff.inMinutes}m ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours}h ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    }
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: AppColors.emeraldGreen, size: 22),
            SizedBox(width: 8),
            Text(
              "Driver Verification Portal",
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Search by name, CNIC or plate...",
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

              // TAB BAR
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.emeraldGreen,
                labelColor: AppColors.emeraldGreen,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: const [
                  Tab(text: "Pending Review"),
                  Tab(text: "Approved"),
                  Tab(text: "Rejected"),
                ],
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.emeraldGreen));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final allDrivers = allDocs.map((d) => {'driverId': d.id, ...d.data()}).toList();

          // Filter by search query
          final filteredDrivers = allDrivers.where((d) {
            if (_searchQuery.isEmpty) return true;
            final name = (d['fullName'] ?? '').toString().toLowerCase();
            final cnic = (d['cnicNumber'] ?? '').toString().toLowerCase();
            final plate = (d['vehicleRegNumber'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || cnic.contains(_searchQuery) || plate.contains(_searchQuery);
          }).toList();

          final pendingList = filteredDrivers.where((d) => (d['verificationStatus'] ?? 'pending') == 'pending').toList();
          final approvedList = filteredDrivers.where((d) => (d['verificationStatus'] ?? 'pending') == 'approved').toList();
          final rejectedList = filteredDrivers.where((d) => (d['verificationStatus'] ?? 'pending') == 'rejected').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDriverList(pendingList, 'pending'),
              _buildDriverList(approvedList, 'approved'),
              _buildDriverList(rejectedList, 'rejected'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverList(List<Map<String, dynamic>> drivers, String tabStatus) {
    if (drivers.isEmpty) {
      String msg;
      IconData icon;
      if (tabStatus == 'pending') {
        msg = "No pending applications to review! 🎉";
        icon = Icons.check_circle_outline_rounded;
      } else if (tabStatus == 'approved') {
        msg = "No approved drivers found.";
        icon = Icons.verified_outlined;
      } else {
        msg = "No rejected applications.";
        icon = Icons.cancel_outlined;
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final driverId = driver['driverId'] as String;
        final name = driver['fullName'] ?? "Driver Applicant";
        final phone = driver['primaryPhone'] ?? "No phone";
        final cnic = driver['cnicNumber'] ?? "No CNIC";
        final vehicleType = driver['vehicleType'] ?? "Vehicle";
        final plate = driver['vehicleRegNumber'] ?? "No plate";
        final status = (driver['verificationStatus'] ?? 'pending').toString().toLowerCase();
        final updatedAt = driver['updatedAt'] as Timestamp?;

        Color statusBg = Colors.orange.shade50;
        Color statusColor = Colors.orange.shade800;
        String statusLabel = "PENDING";

        if (status == 'approved') {
          statusBg = AppColors.mintWhisper;
          statusColor = AppColors.emeraldGreen;
          statusLabel = "APPROVED";
        } else if (status == 'rejected') {
          statusBg = Colors.red.shade50;
          statusColor = Colors.red.shade700;
          statusLabel = "REJECTED";
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminDriverDetailScreen(
                  driverId: driverId,
                  driverData: driver,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: status == 'pending' ? Colors.orange.shade300 : Colors.grey.shade200,
                width: status == 'pending' ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text("CNIC: $cnic", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(width: 12),
                    Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            vehicleType.contains('Bike') ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                            size: 16,
                            color: AppColors.emeraldGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "$vehicleType · $plate",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.black87),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(updatedAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
