require "./spec_helper"

describe Linalg do
  it "calls LAPACK functions directly" do
    m = [
      1.0, 0.0, 1.0,
      0.0, 4.0, 0.0,
      0.0, 0.0, 1.0,
    ]
    ipiv = Slice(Int32).new(3)
    LibLAPACKE.dgetrf(LibLAPACKE::ROW_MAJOR, 3, 3, m, 3, ipiv).should eq 0
    LibLAPACKE.dgetri(LibLAPACKE::ROW_MAJOR, 3, m, 3, ipiv).should eq 0
    m.should eq [1.0, 0.0, -1.0, 0.0, 0.25, 0.0, 0.0, 0.0, 1.0]
  end

  it "calls functions using matrix class" do
    matrix1 = Matrix(Float64).new([
      [1, 0, 1],
      [0, 4, 0],
      [0, 0, 1],
    ])
    matrix2 = matrix1*1
    ipiv = Slice(Int32).new(3)
    LibLAPACKE.dgetrf(LibLAPACKE::ROW_MAJOR, 3, 3, matrix2, 3, ipiv).should eq 0
    LibLAPACKE.dgetri(LibLAPACKE::ROW_MAJOR, 3, matrix2, 3, ipiv).should eq 0
    (matrix1*matrix2).should eq Matrix(Float64).identity(3)
  end

  it "calls functions using high level wrapper" do
    matrix1 = Matrix(Float64).new([
      [1, 0, 1],
      [0, 4, 0],
      [0, 0, 1],
    ])
    (matrix1*matrix1.inv).should eq Matrix(Float64).identity(3)
  end

  it "support all types" do
    matrix1 = Matrix(Float32).new([
      [1, 0, 1],
      [0, 4, 0],
      [0, 0, 1],
    ])
    (matrix1*matrix1.inv).should eq Matrix(Float32).identity(3)

    i = Complex.new(0, 1)
    matrix1 = Matrix(Complex).new({
      {1 + 1*i, 0, 1},
      {0, 4, 0},
      {0, 0, 1},
    })
    (matrix1*matrix1.inv).should eq Matrix(Complex).identity(3)
  end

  it "high-level: solve linear equations" do
    a = Matrix(Float32).new(
      [[2, 4],
       [2, 8]]
    )
    b = Matrix(Float32).new([[2], [4]])
    Linalg.solve(a, b).should eq (a.inv * b)
  end

  it "high-level: calculate determinant" do
    a = Matrix(Float64).new(
      [[1, 2, 3],
       [4, 5, 7],
       [-1, 1, -1]]
    )
    a.det.should eq 9
  end
  it "high-level: solve linear least square" do
    a = Matrix(Float32).new(
      [[1, 2, 0],
       [0, 4, 3]]
    )
    b = Matrix(Float32).new([[8], [18]])
    x = Linalg.lstsq(a, b)
    x_octave = Matrix(Float32).new(3, 1, [0.918032, 3.54098, 1.27869])
    x.should be_close(x_octave, 1e-3)
  end

  it "high-level: solve linear least square (complex)" do
    a = Matrix(Complex).new(
      [[1, 2, 0],
       [0, 4, 3]]
    )
    b = Matrix(Complex).new([[8], [18]])
    x = Linalg.lstsq(a, b)
    x_octave = Matrix(Complex).new(3, 1, [0.918032, 3.54098, 1.27869])
    x.should be_close(x_octave, 1e-3)
  end

  # sadly, spec is order-depentent
  it "high-level: calculate nonsymmetric eigenvalues" do
    a = Matrix(Float32).new([[-2, 4, 1], [2, -4, 1], [1, 1, 1]])
    vals = a.eigvals
    vals[0].should be_close -6, 1e-3
    vals[1].should be_close -1, 1e-3
    vals[2].should be_close 2, 1e-3
  end

  it "high-level: calculate nonsymmetric eigenvalues (complex result)" do
    a = Matrix(Float32).new([[3, -2], [4, -1]])
    vals = a.eigvals
    i = Complex.new(0, 1)
    vals[0].should be_close 1 + 2*i, 1e-3
    vals[1].should be_close 1 - 2*i, 1e-3
  end
  it "high-level: calculate nonsymmetric eigenvalues (complex argument)" do
    a = Matrix(Complex).new([[3, -2], [4, -1]])
    vals = a.eigvals
    i = Complex.new(0, 1)
    vals[0].should be_close 1 + 2*i, 1e-3
    vals[1].should be_close 1 - 2*i, 1e-3
  end

  it "high-level: calculate nonsymmetric eigenvectors" do
    a = Matrix(Float32).new([[-2, 4, 1], [2, -4, 1], [1, 1, 1]])
    vals, vectors = a.eigs
    raise "" if vals.is_a? Array(Complex)
    vals.each { |e| (a*vectors - vectors*e).det.should be_close 0, 1e-4 }

    a = Matrix(Complex).new([[-2, 4, 1], [2, -4, 1], [1, 1, 1]])
    vals, vectors = a.eigs(left: true)
    vals.each { |e| (vectors*a - vectors*e).det.should be_close 0, 1e-6 }
  end

  it "high-level: calculate singular value decomposition" do
    a = Matrix(Float32).new([[1, 2, 3], [4, 5, 6]])
    u, s, vt = Linalg.svd(a)
    (u*Matrix(Float32).diag(a.rows, a.columns, s)*vt).should be_close a, 1e-4
  end

  it "have tril and triu functions" do
    a = Matrix(Float32).new([[1, 2, 3], [4, 5, 6], [7, 8, 9], [10, 11, 12]])
    a.tril(-1).should eq Matrix(Float32).new([
      [0, 0, 0],
      [4, 0, 0],
      [7, 8, 0],
      [10, 11, 12],
    ])
    a.triu.should eq Matrix(Float32).new([
      [1, 2, 3],
      [0, 5, 6],
      [0, 0, 9],
      [0, 0, 0],
    ])
    a.triu(-1).should eq Matrix(Float32).new([
      [1, 2, 3],
      [4, 5, 6],
      [0, 8, 9],
      [0, 0, 12],
    ])
  end
end
