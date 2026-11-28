// Danh mục món đồ có thể tặng trong thư (mã `inventory.item_id` của app).
// Sinh từ `shopItemsFor` trong app/lib/features/shop/shop_catalog.dart (trừ
// trứng pet). Bài kiểm thử app `test/features/mailbox/gift_catalog_test.dart`
// so khớp file này với danh mục thật: thêm món vào cửa hàng mà quên cập nhật
// ở đây thì test báo đỏ.

export interface GiftItem {
  id: string;
  name: string;
}

export interface GiftItemGroup {
  title: string;
  items: GiftItem[];
}

export const GIFT_ITEM_GROUPS: GiftItemGroup[] = [
  {
    title: 'Quần áo bé gái',
    items: [
      { id: 'girl_top_01', name: 'Váy hồng' },
      { id: 'girl_top_02', name: 'Váy tím' },
      { id: 'girl_top_03', name: 'Váy hồng tạp dề' },
      { id: 'girl_top_04', name: 'Váy xòe' },
      { id: 'girl_top_05', name: 'Váy dạ hội' },
      { id: 'girl_top_06', name: 'Váy công chúa' },
      { id: 'girl_top_07', name: 'Váy nữ hoàng tiên' },
      { id: 'girl_top_08', name: 'Yếm jean dã ngoại' },
      { id: 'girl_top_09', name: 'Áo dài Tết' },
      { id: 'girl_top_10', name: 'Váy Ngân hà' },
      { id: 'girl_top_11', name: 'Công chúa rồng' },
    ],
  },
  {
    title: 'Quần áo bé trai',
    items: [
      { id: 'boy_outfit_01', name: 'Áo xanh, quần short' },
      { id: 'boy_outfit_02', name: 'Áo hoodie xanh lá' },
      { id: 'boy_outfit_03', name: 'Áo đỏ, quần jean' },
      { id: 'boy_outfit_04', name: 'Sơ mi nơ' },
      { id: 'boy_outfit_05', name: 'Vest dạ hội' },
      { id: 'boy_outfit_06', name: 'Hoàng tử' },
      { id: 'boy_outfit_07', name: 'Hiệp sĩ hoàng gia' },
      { id: 'boy_outfit_08', name: 'Polo dã ngoại' },
      { id: 'boy_outfit_09', name: 'Áo dài gấm' },
      { id: 'boy_outfit_10', name: 'Phi hành gia' },
      { id: 'boy_outfit_11', name: 'Hiệp sĩ rồng' },
    ],
  },
  {
    title: 'Phụ kiện',
    items: [
      { id: 'head_hat', name: 'Mũ beret' },
      { id: 'head_bow', name: 'Nơ cài tóc' },
      { id: 'glasses', name: 'Kính tròn' },
      { id: 'white_shoes', name: 'Giày trắng' },
      { id: 'backpack', name: 'Balo' },
    ],
  },
  {
    title: 'Đồ cho pet',
    items: [
      { id: 'pet_food_bone', name: 'Xương' },
      { id: 'pet_food_fish', name: 'Cá' },
      { id: 'pet_food_carrot', name: 'Cà rốt' },
      { id: 'pet_toy_ball', name: 'Quả bóng' },
      { id: 'pet_toy_yarn', name: 'Cuộn len' },
      { id: 'pet_toy_plush', name: 'Thú bông' },
    ],
  },
  {
    title: 'Nội thất',
    items: [
      { id: 'noi_be_ca', name: 'Bể cá' },
      { id: 'noi_den_trang', name: 'Đèn mặt trăng' },
      { id: 'noi_ke_sach', name: 'Kệ sách' },
      { id: 'noi_ghe_luoi', name: 'Ghế lười' },
      { id: 'noi_nha_pet', name: 'Nhà cho pet' },
      { id: 'noi_cay_cao', name: 'Chậu cây lá to' },
      { id: 'noi_leu', name: 'Lều đồ chơi' },
      { id: 'noi_tranh', name: 'Tranh cầu vồng' },
    ],
  },
  {
    title: 'Bộ phòng chủ đề',
    items: [
      { id: 'room_theme_tet', name: 'Phòng Tết' },
      { id: 'room_theme_ngan_ha', name: 'Phòng Ngân hà' },
      { id: 'room_theme_rong', name: 'Phòng Rồng' },
    ],
  },
  {
    title: 'Món lẻ của bộ phòng',
    items: [
      { id: 'room_item_tet_noi_tham', name: 'Thảm Tết' },
      { id: 'room_item_tet_noi_ke_lon', name: 'Kệ sách lớn Tết' },
      { id: 'room_item_tet_noi_giuong', name: 'Giường Tết' },
      { id: 'room_item_tet_noi_tu_dau_giuong', name: 'Tủ đầu giường Tết' },
      { id: 'room_item_tet_noi_ban_hoc', name: 'Bàn học Tết' },
      { id: 'room_item_tet_noi_ghe', name: 'Ghế Tết' },
      { id: 'room_item_tet_noi_tu_ao', name: 'Tủ áo Tết' },
      { id: 'room_item_tet_gau-bong', name: 'Gấu bông Tết' },
      { id: 'room_item_tet_den-sao', name: 'Đèn sao Tết' },
      { id: 'room_item_tet_chau-cay', name: 'Chậu cây Tết' },
      { id: 'room_item_tet_binh-hoa', name: 'Bình hoa Tết' },
      { id: 'room_item_tet_coc-sao', name: 'Cốc bút Tết' },
      { id: 'room_item_tet_noi_nha_pet', name: 'Nhà cho pet Tết' },
      { id: 'room_item_tet_noi_ke_sach', name: 'Kệ sách Tết' },
      { id: 'room_item_tet_noi_be_ca', name: 'Bể cá Tết' },
      { id: 'room_item_tet_noi_cay_cao', name: 'Chậu cây lá to Tết' },
      { id: 'room_item_tet_noi_ghe_luoi', name: 'Ghế lười Tết' },
      { id: 'room_item_tet_noi_leu', name: 'Lều đồ chơi Tết' },
      { id: 'room_item_tet_noi_den_trang', name: 'Đèn mặt trăng Tết' },
      { id: 'room_item_tet_noi_tranh', name: 'Tranh cầu vồng Tết' },
      { id: 'room_item_ngan_ha_noi_tham', name: 'Thảm Ngân hà' },
      { id: 'room_item_ngan_ha_noi_ke_lon', name: 'Kệ sách lớn Ngân hà' },
      { id: 'room_item_ngan_ha_noi_giuong', name: 'Giường Ngân hà' },
      { id: 'room_item_ngan_ha_noi_tu_dau_giuong', name: 'Tủ đầu giường Ngân hà' },
      { id: 'room_item_ngan_ha_noi_ban_hoc', name: 'Bàn học Ngân hà' },
      { id: 'room_item_ngan_ha_noi_ghe', name: 'Ghế Ngân hà' },
      { id: 'room_item_ngan_ha_noi_tu_ao', name: 'Tủ áo Ngân hà' },
      { id: 'room_item_ngan_ha_gau-bong', name: 'Gấu bông Ngân hà' },
      { id: 'room_item_ngan_ha_chau-cay', name: 'Chậu cây Ngân hà' },
      { id: 'room_item_ngan_ha_binh-hoa', name: 'Bình hoa Ngân hà' },
      { id: 'room_item_ngan_ha_noi_nha_pet', name: 'Nhà cho pet Ngân hà' },
      { id: 'room_item_ngan_ha_noi_ke_sach', name: 'Kệ sách Ngân hà' },
      { id: 'room_item_ngan_ha_noi_be_ca', name: 'Bể cá Ngân hà' },
      { id: 'room_item_ngan_ha_noi_cay_cao', name: 'Chậu cây lá to Ngân hà' },
      { id: 'room_item_ngan_ha_noi_ghe_luoi', name: 'Ghế lười Ngân hà' },
      { id: 'room_item_ngan_ha_noi_leu', name: 'Lều đồ chơi Ngân hà' },
      { id: 'room_item_ngan_ha_noi_den_trang', name: 'Đèn mặt trăng Ngân hà' },
      { id: 'room_item_ngan_ha_noi_tranh', name: 'Tranh cầu vồng Ngân hà' },
      { id: 'room_item_rong_noi_tham', name: 'Thảm Rồng' },
      { id: 'room_item_rong_noi_ke_lon', name: 'Kệ sách lớn Rồng' },
      { id: 'room_item_rong_noi_giuong', name: 'Giường Rồng' },
      { id: 'room_item_rong_noi_tu_dau_giuong', name: 'Tủ đầu giường Rồng' },
      { id: 'room_item_rong_noi_ban_hoc', name: 'Bàn học Rồng' },
      { id: 'room_item_rong_noi_ghe', name: 'Ghế Rồng' },
      { id: 'room_item_rong_noi_tu_ao', name: 'Tủ áo Rồng' },
      { id: 'room_item_rong_noi_nha_pet', name: 'Nhà cho pet Rồng' },
      { id: 'room_item_rong_noi_ke_sach', name: 'Kệ sách Rồng' },
      { id: 'room_item_rong_noi_be_ca', name: 'Bể cá Rồng' },
      { id: 'room_item_rong_noi_cay_cao', name: 'Chậu cây lá to Rồng' },
      { id: 'room_item_rong_noi_ghe_luoi', name: 'Ghế lười Rồng' },
      { id: 'room_item_rong_noi_leu', name: 'Lều đồ chơi Rồng' },
      { id: 'room_item_rong_noi_den_trang', name: 'Đèn mặt trăng Rồng' },
      { id: 'room_item_rong_noi_tranh', name: 'Tranh cầu vồng Rồng' },
    ],
  },
];

export const GIFT_ITEMS: GiftItem[] = GIFT_ITEM_GROUPS.flatMap((g) => g.items);

/** Tên món theo mã; mã lạ thì trả lại chính mã. */
export function giftItemName(id: string): string {
  return GIFT_ITEMS.find((i) => i.id === id)?.name ?? id;
}
