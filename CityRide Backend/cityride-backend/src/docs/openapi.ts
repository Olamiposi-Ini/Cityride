export const openApiDocument = {
  openapi: "3.1.0",
  info: {
    title: "CityRide API",
    version: "1.0.0",
    description:
      "Backend API for CityRide, a hyperlocal ride-booking platform for Redemption City. Use this documentation to test authentication, admin, driver, ride, chat, and simulated call flows."
  },
  servers: [
    {
      url: "/",
      description: "Current API host"
    }
  ],
  tags: [
    { name: "Health" },
    { name: "Auth" },
    { name: "Admin" },
    { name: "Drivers" },
    { name: "Rides" },
    { name: "Messages" },
    { name: "Calls" }
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT"
      }
    },
    schemas: {
      Error: {
        type: "object",
        properties: {
          message: { type: "string" },
          details: {}
        }
      },
      UserRole: {
        type: "string",
        enum: ["RIDER", "DRIVER", "ADMIN"]
      },
      RideStatus: {
        type: "string",
        enum: [
          "SEARCHING",
          "DRIVER_ASSIGNED",
          "DRIVER_EN_ROUTE",
          "DRIVER_ARRIVED",
          "IN_PROGRESS",
          "COMPLETED",
          "CANCELLED"
        ]
      },
      Location: {
        type: "object",
        required: ["lat", "lng"],
        properties: {
          lat: { type: "number", example: 6.812 },
          lng: { type: "number", example: 3.439 },
          label: { type: "string", example: "Main Gate" }
        }
      },
      AuthResponse: {
        type: "object",
        properties: {
          user: { $ref: "#/components/schemas/User" },
          token: { type: "string" }
        }
      },
      RegistrationResponse: {
        type: "object",
        properties: {
          user: { $ref: "#/components/schemas/User" },
          verification: { $ref: "#/components/schemas/ApiResponseVerification" }
        }
      },
      ApiResponseVerification: {
        type: "object",
        description:
          "Temporary development/staging verification payload. Later this OTP can be sent by email instead of returned by the API.",
        properties: {
          deliveryMode: { type: "string", example: "api_response" },
          expiresAt: { type: "string", format: "date-time" },
          otp: { type: "string", example: "483921" }
        }
      },
      User: {
        type: "object",
        properties: {
          id: { type: "string" },
          firstName: { type: "string" },
          lastName: { type: "string" },
          email: { type: "string", format: "email" },
          phone: { type: "string" },
          emailVerifiedAt: { type: "string", format: "date-time", nullable: true },
          role: { $ref: "#/components/schemas/UserRole" },
          createdAt: { type: "string", format: "date-time" },
          driver: { $ref: "#/components/schemas/DriverProfile" }
        }
      },
      DriverProfile: {
        type: "object",
        nullable: true,
        properties: {
          id: { type: "string" },
          userId: { type: "string" },
          vehicleType: {
            type: "string",
            enum: ["CAB", "BUS", "KEKE"],
            nullable: true
          },
          plateNumber: { type: "string", nullable: true },
          isAvailable: { type: "boolean" },
          lastLatitude: { type: "number", nullable: true },
          lastLongitude: { type: "number", nullable: true },
          lastLocationAt: { type: "string", format: "date-time", nullable: true }
        }
      },
      Ride: {
        type: "object",
        properties: {
          id: { type: "string" },
          riderId: { type: "string" },
          driverId: { type: "string", nullable: true },
          pickupLatitude: { type: "number" },
          pickupLongitude: { type: "number" },
          destinationLatitude: { type: "number" },
          destinationLongitude: { type: "number" },
          pickupLabel: { type: "string", nullable: true },
          destinationLabel: { type: "string", nullable: true },
          status: { $ref: "#/components/schemas/RideStatus" },
          fareEstimate: { type: "integer", example: 700 },
          distanceKm: { type: "number", example: 1.52 },
          createdAt: { type: "string", format: "date-time" },
          updatedAt: { type: "string", format: "date-time" },
          rider: { $ref: "#/components/schemas/User" },
          driver: { $ref: "#/components/schemas/User" }
        }
      },
      ChatMessage: {
        type: "object",
        properties: {
          id: { type: "string" },
          rideId: { type: "string" },
          senderId: { type: "string" },
          message: { type: "string" },
          status: { type: "string", enum: ["SENT", "DELIVERED", "READ"] },
          createdAt: { type: "string", format: "date-time" }
        }
      },
      CallSession: {
        type: "object",
        properties: {
          id: { type: "string" },
          rideId: { type: "string" },
          initiatorId: { type: "string" },
          status: {
            type: "string",
            enum: ["CALLING", "RINGING", "CONNECTED", "ENDED", "MISSED"]
          },
          createdAt: { type: "string", format: "date-time" },
          updatedAt: { type: "string", format: "date-time" },
          endedAt: { type: "string", format: "date-time", nullable: true }
        }
      }
    },
    parameters: {
      RideId: {
        name: "rideId",
        in: "path",
        required: true,
        schema: { type: "string" }
      }
    },
    requestBodies: {
      RideLocations: {
        required: true,
        content: {
          "application/json": {
            schema: {
              type: "object",
              required: ["pickupLocation", "destination"],
              properties: {
                pickupLocation: { $ref: "#/components/schemas/Location" },
                destination: { $ref: "#/components/schemas/Location" }
              }
            }
          }
        }
      }
    }
  },
  paths: {
    "/health": {
      get: {
        tags: ["Health"],
        summary: "Health check",
        responses: {
          "200": {
            description: "Server is running"
          }
        }
      }
    },
    "/auth/register": {
      post: {
        tags: ["Auth"],
        summary: "Register a rider or driver",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["firstName", "lastName", "email", "phone", "password", "role"],
                properties: {
                  firstName: { type: "string", example: "Rider" },
                  lastName: { type: "string", example: "One" },
                  email: {
                    type: "string",
                    format: "email",
                    example: "rider.one@example.com"
                  },
                  phone: { type: "string", example: "08020000001" },
                  password: { type: "string", example: "secret123" },
                  role: { type: "string", enum: ["RIDER", "DRIVER"] },
                  vehicleType: {
                    type: "string",
                    enum: ["CAB", "BUS", "KEKE"],
                    example: "KEKE"
                  },
                  plateNumber: { type: "string", example: "RC-123" }
                }
              }
            }
          }
        },
        responses: {
          "201": {
            description:
              "Registered user. No token is returned until email verification succeeds.",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/RegistrationResponse" }
              }
            }
          }
        }
      }
    },
    "/auth/bootstrap-admin": {
      post: {
        tags: ["Auth"],
        summary: "Create the first admin",
        description:
          "Protected by ADMIN_BOOTSTRAP_SECRET and only works while no admin account exists.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["firstName", "lastName", "email", "phone", "password", "bootstrapSecret"],
                properties: {
                  firstName: { type: "string", example: "CityRide" },
                  lastName: { type: "string", example: "Admin" },
                  email: {
                    type: "string",
                    format: "email",
                    example: "admin@cityride.local"
                  },
                  phone: { type: "string", example: "08000000000" },
                  password: { type: "string", example: "adminsecret123" },
                  bootstrapSecret: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "201": {
            description:
              "Admin created. No token is returned until email verification succeeds."
          },
          "409": { description: "Admin already exists" }
        }
      }
    },
    "/auth/login": {
      post: {
        tags: ["Auth"],
        summary: "Log in any role",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "rider.one@example.com"
                  },
                  password: { type: "string", example: "secret123" }
                }
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Logged in",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" }
              }
            }
          },
          "403": {
            description:
              "Email is not verified. Response includes a fresh API-response OTP and no token."
          }
        }
      }
    },
    "/auth/verify-email": {
      post: {
        tags: ["Auth"],
        summary: "Verify user email with OTP",
        description:
          "For now the OTP is returned by registration/resend responses. Later it can be delivered by email.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "code"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "rider.one@example.com"
                  },
                  code: { type: "string", example: "483921" }
                }
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Email verified. Response includes JWT token.",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" }
              }
            }
          },
          "400": { description: "Invalid code" },
          "409": { description: "Expired or missing code" }
        }
      }
    },
    "/auth/resend-verification-code": {
      post: {
        tags: ["Auth"],
        summary: "Generate a new email verification OTP",
        description:
          "Temporary development/staging behavior returns the OTP in the API response.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "rider.one@example.com"
                  }
                }
              }
            }
          }
        },
        responses: {
          "200": {
            description: "Verification code generated",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    message: { type: "string" },
                    verification: {
                      $ref: "#/components/schemas/ApiResponseVerification"
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/auth/me": {
      get: {
        tags: ["Auth"],
        summary: "Get current logged-in user",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Current user" }
        }
      }
    },
    "/admin/overview": {
      get: {
        tags: ["Admin"],
        summary: "Get admin dashboard counts",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Platform overview" }
        }
      }
    },
    "/admin/users": {
      get: {
        tags: ["Admin"],
        summary: "List users",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "role",
            in: "query",
            schema: { $ref: "#/components/schemas/UserRole" }
          },
          { name: "limit", in: "query", schema: { type: "integer", default: 50 } },
          { name: "offset", in: "query", schema: { type: "integer", default: 0 } }
        ],
        responses: {
          "200": { description: "Users list" }
        }
      },
      post: {
        tags: ["Admin"],
        summary: "Create a rider, driver, or admin",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["firstName", "lastName", "email", "phone", "password", "role"],
                properties: {
                  firstName: { type: "string" },
                  lastName: { type: "string" },
                  email: { type: "string", format: "email" },
                  phone: { type: "string" },
                  password: { type: "string" },
                  role: { $ref: "#/components/schemas/UserRole" },
                  vehicleType: {
                    type: "string",
                    enum: ["CAB", "BUS", "KEKE"]
                  },
                  plateNumber: { type: "string" }
                }
              }
            }
          }
        },
        responses: {
          "201": { description: "User created" }
        }
      }
    },
    "/admin/drivers": {
      get: {
        tags: ["Admin"],
        summary: "List driver profiles",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Drivers list" }
        }
      }
    },
    "/admin/rides": {
      get: {
        tags: ["Admin"],
        summary: "List rides",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "status",
            in: "query",
            schema: { $ref: "#/components/schemas/RideStatus" }
          },
          { name: "limit", in: "query", schema: { type: "integer", default: 50 } },
          { name: "offset", in: "query", schema: { type: "integer", default: 0 } }
        ],
        responses: {
          "200": { description: "Rides list" }
        }
      }
    },
    "/drivers/me/availability": {
      patch: {
        tags: ["Drivers"],
        summary: "Set driver availability",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["isAvailable"],
                properties: {
                  isAvailable: { type: "boolean", example: true }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Driver profile updated" }
        }
      }
    },
    "/drivers/me/location": {
      patch: {
        tags: ["Drivers"],
        summary: "Update driver GPS location",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["lat", "lng"],
                properties: {
                  lat: { type: "number", example: 6.8123 },
                  lng: { type: "number", example: 3.4389 }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Location updated" }
        }
      }
    },
    "/drivers/nearby": {
      get: {
        tags: ["Drivers"],
        summary: "Find nearby available drivers",
        security: [{ bearerAuth: [] }],
        parameters: [
          { name: "lat", in: "query", required: true, schema: { type: "number" } },
          { name: "lng", in: "query", required: true, schema: { type: "number" } },
          { name: "radiusKm", in: "query", schema: { type: "number", default: 5 } }
        ],
        responses: {
          "200": { description: "Nearby drivers" }
        }
      }
    },
    "/drivers/me/requests": {
      get: {
        tags: ["Drivers"],
        summary: "Get assigned incoming ride requests",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Incoming ride requests" }
        }
      }
    },
    "/rides/quick-replies": {
      get: {
        tags: ["Messages"],
        summary: "Get PRD quick replies for rider and driver chat",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Quick replies grouped by role",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    quickReplies: {
                      type: "object",
                      properties: {
                        rider: {
                          type: "array",
                          items: { type: "string" },
                          example: [
                            "I'm at the gate.",
                            "Please wait 2 minutes.",
                            "I can see you."
                          ]
                        },
                        driver: {
                          type: "array",
                          items: { type: "string" },
                          example: [
                            "I've arrived.",
                            "I'm nearby.",
                            "Traffic is slowing me down."
                          ]
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    },
    "/rides/estimate": {
      post: {
        tags: ["Rides"],
        summary: "Estimate ride fare",
        security: [{ bearerAuth: [] }],
        requestBody: { $ref: "#/components/requestBodies/RideLocations" },
        responses: {
          "200": { description: "Fare estimate" }
        }
      }
    },
    "/rides": {
      post: {
        tags: ["Rides"],
        summary: "Create ride request",
        security: [{ bearerAuth: [] }],
        requestBody: { $ref: "#/components/requestBodies/RideLocations" },
        responses: {
          "201": { description: "Ride created" }
        }
      }
    },
    "/rides/me/active": {
      get: {
        tags: ["Rides"],
        summary: "Get current user's active rides",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Active rides" }
        }
      }
    },
    "/rides/{rideId}": {
      get: {
        tags: ["Rides"],
        summary: "Get ride by ID",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "200": { description: "Ride details" }
        }
      }
    },
    "/rides/{rideId}/accept": {
      patch: {
        tags: ["Rides"],
        summary: "Driver accepts assigned ride",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "200": { description: "Ride accepted" }
        }
      }
    },
    "/rides/{rideId}/decline": {
      patch: {
        tags: ["Rides"],
        summary: "Driver declines assigned ride",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "200": { description: "Ride declined and possibly reassigned" }
        }
      }
    },
    "/rides/{rideId}/status": {
      patch: {
        tags: ["Rides"],
        summary: "Driver updates ride status",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["status"],
                properties: {
                  status: {
                    type: "string",
                    enum: [
                      "DRIVER_EN_ROUTE",
                      "DRIVER_ARRIVED",
                      "IN_PROGRESS",
                      "COMPLETED"
                    ]
                  }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Ride status updated" }
        }
      }
    },
    "/rides/{rideId}/cancel": {
      patch: {
        tags: ["Rides"],
        summary: "Cancel ride",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "200": { description: "Ride cancelled" }
        }
      }
    },
    "/rides/{rideId}/messages": {
      get: {
        tags: ["Messages"],
        summary: "List active ride messages",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "200": { description: "Messages list" }
        }
      },
      post: {
        tags: ["Messages"],
        summary: "Send active ride message",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["message"],
                properties: {
                  message: { type: "string", example: "I am at the gate." }
                }
              }
            }
          }
        },
        responses: {
          "201": { description: "Message sent" }
        }
      }
    },
    "/rides/{rideId}/calls": {
      post: {
        tags: ["Calls"],
        summary: "Create simulated call session",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/RideId" }],
        responses: {
          "201": { description: "Call session created" }
        }
      }
    },
    "/rides/calls/{callId}": {
      patch: {
        tags: ["Calls"],
        summary: "Update simulated call state",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "callId",
            in: "path",
            required: true,
            schema: { type: "string" }
          }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["status"],
                properties: {
                  status: {
                    type: "string",
                    enum: ["RINGING", "CONNECTED", "ENDED", "MISSED"]
                  }
                }
              }
            }
          }
        },
        responses: {
          "200": { description: "Call state updated" }
        }
      }
    }
  }
} as const;
