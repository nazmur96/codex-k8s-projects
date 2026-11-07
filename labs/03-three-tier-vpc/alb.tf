resource "aws_lb" "this" {
  name               = "three-tier-vpc-lab-dev"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.this["public_a"].id,
    aws_subnet.this["public_b"].id,
  ]

  depends_on = [
    aws_internet_gateway.this,
    aws_route.public_internet,
    aws_route_table_association.public,
  ]

  tags = {
    Name = "three-tier-vpc-lab-dev-alb"
  }
}
resource "aws_lb_target_group" "api" {
  name        = "three-tier-api-dev"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "three-tier-vpc-lab-dev-api"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}
