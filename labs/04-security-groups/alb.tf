resource "aws_lb" "this" {
  name                       = "seclab-dev"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.this["public_a"].id, aws_subnet.this["public_b"].id]
  drop_invalid_header_fields = true

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "security-groups-lab-dev"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "seclab-app"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.this["app"].id
  port             = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
