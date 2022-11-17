resource "bigip_ltm_policy" "canary" {
    controls = ["asm"]
    name     = "/${var.partition}/${var.name}"
    requires = ["http"]
    strategy = "first-match"

    rule {
        name = "ea"

        action {
            asm                  = true
            policy               = "/${var.partition}/${var.new_waf_policy}"
            request              = true
            connection		     = false
        }

        condition {
            all                  = true
            case_insensitive     = true
            equals               = true
            external             = true
            http_header          = true
            present              = true
            remote               = true
            request              = true
            tm_name              = "${var.header_name}"
            values               = ["${var.header_value}"]
        }
    }
    rule {
        name = "default"

        action {
            asm                  = true
            enable               = true
            policy               = "/${var.partition}/${var.current_waf_policy}"
            request              = true
            connection		     = false
        }
    }
}
