import 'package:new_coffee/features/checkout/data/model/address_model.dart';

List<AddressModel> getAddressesList() {
  return const [
    AddressModel(
      id: "1",
      label: "Home",
      details: "1901 Jizan, Al-Arda, Bathan, main street",
    ),
    AddressModel(
      id: "2",
      label: "Work",
      details: "King Fahd Road, Al Olaya district, office 12",
    ),
  ];
}
