# 找到第一个注册的用户并将其设置为超级管理员
first_user = User.order(:created_at).first

if first_user
  first_user.update!(role: 'super_admin', admin: true)
  puts "已将用户 #{first_user.email} 设置为超级管理员 (super_admin)"
else
  puts "未找到任何用户，请先注册或在 seeds 中创建用户。"
end
